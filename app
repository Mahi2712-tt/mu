// Contract ABI and address
const contractAddress = '0x5B38Da6a701c568545dCfcB03FcB875f56beddC4'; // To be filled after deployment
const contractABI = []; // To be filled after deployment

let contract;
let signer;
let provider;

// DOM Elements
const connectWalletBtn = document.getElementById('connect-wallet');
const walletAddressText = document.getElementById('wallet-address');
const statusMessage = document.getElementById('status-message');
const uploadSection = document.getElementById('upload-section');

// Initialize Web3 and contract
async function initWeb3() {
    try {
        // Check if MetaMask is installed
        if (typeof window.ethereum === 'undefined') {
            throw new Error('Please install MetaMask to use this application');
        }

        // Get provider and signer
        provider = new ethers.providers.Web3Provider(window.ethereum);
        signer = provider.getSigner();
        contract = new ethers.Contract(contractAddress, contractABI, signer);

        // Check if already connected
        const accounts = await provider.listAccounts();
        if (accounts.length > 0) {
            handleAccountsChanged(accounts);
        }

        // Listen for account changes
        window.ethereum.on('accountsChanged', handleAccountsChanged);
    } catch (error) {
        showStatus(error.message, 'error');
    }
}

// Handle wallet connection
async function connectWallet() {
    try {
        const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
        handleAccountsChanged(accounts);
    } catch (error) {
        showStatus('Failed to connect wallet: ' + error.message, 'error');
    }
}

// Handle account changes
function handleAccountsChanged(accounts) {
    if (accounts.length === 0) {
        // Disconnected
        connectWalletBtn.classList.remove('hidden');
        walletAddressText.classList.add('hidden');
        if (uploadSection) {
            uploadSection.classList.add('hidden');
        }
    } else {
        // Connected
        const address = accounts[0];
        connectWalletBtn.classList.add('hidden');
        walletAddressText.classList.remove('hidden');
        walletAddressText.textContent = `Connected: ${address.slice(0, 6)}...${address.slice(-4)}`;
        
        // Show upload section if on artist page
        if (uploadSection) {
            checkArtistRegistration();
        }

        // Load music if on listening page
        if (document.getElementById('music-grid')) {
            loadMusic();
        }
    }
}

// Artist Registration
async function registerArtist(event) {
    if (event) event.preventDefault();
    
    try {
        const artistName = document.getElementById('artist-name').value;
        if (!artistName) throw new Error('Please enter an artist name');

        showStatus('Registering artist...', 'info');
        const tx = await contract.registerArtist(artistName);
        await tx.wait();

        showStatus('Successfully registered as an artist!', 'success');
        uploadSection.classList.remove('hidden');
    } catch (error) {
        showStatus('Failed to register: ' + error.message, 'error');
    }
}

// Check if wallet is registered as artist
async function checkArtistRegistration() {
    try {
        const address = await signer.getAddress();
        const artistInfo = await contract.artists(address);
        if (artistInfo.isRegistered) {
            uploadSection.classList.remove('hidden');
        }
    } catch (error) {
        console.error('Error checking artist registration:', error);
    }
}

// Upload Music
async function uploadMusic(event) {
    if (event) event.preventDefault();
    
    try {
        const title = document.getElementById('music-title').value;
        const metadataUrl = document.getElementById('music-url').value;
        const coverImageUrl = document.getElementById('cover-image').value;
        const price = ethers.utils.parseEther(document.getElementById('price').value);

        if (!title || !metadataUrl || !coverImageUrl || !price) {
            throw new Error('Please fill in all fields');
        }

        showStatus('Uploading music...', 'info');
        const tx = await contract.uploadMusic(title, metadataUrl, coverImageUrl, price);
        await tx.wait();

        showStatus('Music uploaded successfully!', 'success');
        event.target.reset();
    } catch (error) {
        showStatus('Failed to upload: ' + error.message, 'error');
    }
}

// Load Music (for listening page)
async function loadMusic() {
    try {
        const musicGrid = document.getElementById('music-grid');
        const loadingPlaceholder = document.getElementById('loading-placeholder');
        const noResults = document.getElementById('no-results');
        const template = document.getElementById('music-card-template');

        if (!musicGrid || !template) return;

        musicGrid.innerHTML = '';
        loadingPlaceholder.classList.remove('hidden');
        noResults.classList.add('hidden');

        const musicCount = await contract.getMusicCount();
        const musicItems = [];

        for (let i = 1; i <= musicCount; i++) {
            try {
                const music = await contract.getMusicDetails(i);
                if (music.isActive) {
                    musicItems.push({
                        id: i,
                        title: music.title,
                        artist: await contract.getArtistName(music.artistAddress),
                        coverImageUrl: music.coverImageUrl,
                        price: ethers.utils.formatEther(music.price),
                        metadataUrl: music.metadataUrl
                    });
                }
            } catch (error) {
                console.error(`Error loading music ${i}:`, error);
            }
        }

        loadingPlaceholder.classList.add('hidden');

        if (musicItems.length === 0) {
            noResults.classList.remove('hidden');
            return;
        }

        musicItems.forEach(item => {
            const card = template.content.cloneNode(true);
            
            const img = card.querySelector('img');
            img.src = item.coverImageUrl;
            img.alt = `${item.title} Cover`;

            card.querySelector('h3').textContent = item.title;
            card.querySelector('p').textContent = `By ${item.artist}`;
            card.querySelector('.text-purple-500').textContent = `${item.price} ETH`;

            const previewBtn = card.querySelector('button');
            previewBtn.onclick = () => showMusicModal(item);

            musicGrid.appendChild(card);
        });
    } catch (error) {
        showStatus('Failed to load music: ' + error.message, 'error');
    }
}

// Show Music Modal
function showMusicModal(music) {
    const modal = document.getElementById('player-modal');
    const title = document.getElementById('modal-title');
    const cover = document.getElementById('modal-cover');
    const artist = document.getElementById('modal-artist');
    const price = document.getElementById('modal-price');
    const purchaseBtn = document.getElementById('purchase-button');

    title.textContent = music.title;
    cover.src = music.coverImageUrl;
    artist.textContent = `By ${music.artist}`;
    price.textContent = `${music.price} ETH`;

    purchaseBtn.onclick = () => purchaseMusic(music.id, music.price);
    modal.classList.remove('hidden');

    document.getElementById('close-modal').onclick = () => {
        modal.classList.add('hidden');
    };
}

// Purchase Music
async function purchaseMusic(musicId, price) {
    try {
        showStatus('Processing purchase...', 'info');
        const tx = await contract.purchaseMusic(musicId, {
            value: ethers.utils.parseEther(price)
        });
        await tx.wait();
        showStatus('Purchase successful!', 'success');
        document.getElementById('player-modal').classList.add('hidden');
    } catch (error) {
        showStatus('Failed to purchase: ' + error.message, 'error');
    }
}

// Show Status Message
function showStatus(message, type = 'info') {
    const statusDiv = document.getElementById('status-message');
    const messageP = statusDiv.querySelector('p');
    
    statusDiv.classList.remove('hidden', 'bg-green-100', 'bg-red-100', 'bg-blue-100');
    messageP.classList.remove('text-green-700', 'text-red-700', 'text-blue-700');

    switch (type) {
        case 'success':
            statusDiv.classList.add('bg-green-100');
            messageP.classList.add('text-green-700');
            break;
        case 'error':
            statusDiv.classList.add('bg-red-100');
            messageP.classList.add('text-red-700');
            break;
        default:
            statusDiv.classList.add('bg-blue-100');
            messageP.classList.add('text-blue-700');
    }

    messageP.textContent = message;
    statusDiv.classList.remove('hidden');

    // Hide after 5 seconds
    setTimeout(() => {
        statusDiv.classList.add('hidden');
    }, 5000);
}

// Event Listeners
document.addEventListener('DOMContentLoaded', () => {
    initWeb3();

    connectWalletBtn.addEventListener('click', connectWallet);

    const registrationForm = document.getElementById('registration-form');
    if (registrationForm) {
        registrationForm.addEventListener('submit', registerArtist);
    }

    const uploadForm = document.getElementById('upload-form');
    if (uploadForm) {
        uploadForm.addEventListener('submit', uploadMusic);
    }

    // Search functionality
    const searchInput = document.getElementById('search');
    if (searchInput) {
        searchInput.addEventListener('input', (e) => {
            const searchTerm = e.target.value.toLowerCase();
            const cards = document.querySelectorAll('.music-card');
            
            cards.forEach(card => {
                const title = card.querySelector('h3').textContent.toLowerCase();
                const artist = card.querySelector('p').textContent.toLowerCase();
                
                if (title.includes(searchTerm) || artist.includes(searchTerm)) {
                    card.style.display = '';
                } else {
                    card.style.display = 'none';
                }
            });
        });
    }
});
