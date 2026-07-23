// THREE.JS 3D VIEWPORT & LANDING INTERACTION SYSTEM

let scene, camera, renderer, controls;
let activeMesh = null;
let pedestalMesh = null;

const characterData = {
    'robot_blue': {
        name: 'ROBOT EXPLORADOR AZUL (MODELO 3D)',
        color: 0x00f2fe,
        shape: 'capsule',
        hp: '75%',
        speed: '90%',
        power: '80%'
    },
    'robot_pink': {
        name: 'ROBOT ESPECIALISTA ROSA (MODELO 3D)',
        color: 0xff40b3,
        shape: 'capsule',
        hp: '65%',
        speed: '95%',
        power: '85%'
    },
    'beast_mecha': {
        name: 'MECHA DESTRUCTOR 3D (BESTIA)',
        color: 0xff3344,
        shape: 'box',
        hp: '100%',
        speed: '70%',
        power: '100%'
    },
    'skel_warrior': {
        name: 'ESQUELETO GUERRERO 3D (RIVAL)',
        color: 0xffab00,
        shape: 'skeleton',
        hp: '80%',
        speed: '85%',
        power: '75%'
    }
};

function init3DViewport() {
    const canvas = document.getElementById('three-canvas');
    if (!canvas) return;

    const width = canvas.parentElement.clientWidth;
    const height = canvas.parentElement.clientHeight;

    // Scene
    scene = new THREE.Scene();
    scene.background = new THREE.Color(0x06090e);
    scene.fog = new THREE.FogExp2(0x06090e, 0.05);

    // Camera
    camera = new THREE.PerspectiveCamera(45, width / height, 0.1, 1000);
    camera.position.set(0, 2.5, 6);

    // Renderer
    renderer = new THREE.WebGLRenderer({ canvas: canvas, antialias: true });
    renderer.setSize(width, height);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.shadowMap.enabled = true;

    // Controls
    controls = new THREE.OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;
    controls.dampingFactor = 0.05;
    controls.maxPolarAngle = Math.PI / 2 + 0.1;
    controls.minDistance = 3;
    controls.maxDistance = 10;

    // Lighting
    const ambientLight = new THREE.AmbientLight(0x223344, 1.5);
    scene.add(ambientLight);

    const dirLight = new THREE.DirectionalLight(0xffffff, 2.0);
    dirLight.position.set(5, 10, 7);
    dirLight.castShadow = true;
    scene.add(dirLight);

    const pointLight = new THREE.PointLight(0x00f2fe, 3, 10);
    pointLight.position.set(-3, 2, 3);
    scene.add(pointLight);

    const rimLight = new THREE.PointLight(0xffab00, 2, 8);
    rimLight.position.set(3, 1, -3);
    scene.add(rimLight);

    // Grid Floor
    const gridHelper = new THREE.GridHelper(20, 20, 0x00f2fe, 0x112233);
    gridHelper.position.y = -0.01;
    scene.add(gridHelper);

    // 3D Pedestal
    const pedGeo = new THREE.CylinderGeometry(1.6, 1.8, 0.3, 32);
    const pedMat = new THREE.MeshStandardMaterial({
        color: 0x0e1c2a,
        metalness: 0.8,
        roughness: 0.2,
        emissive: 0x00f2fe,
        emissiveIntensity: 0.2
    });
    pedestalMesh = new THREE.Mesh(pedGeo, pedMat);
    pedestalMesh.position.y = -0.15;
    pedestalMesh.receiveShadow = true;
    scene.add(pedestalMesh);

    // Initial 3D Model
    createCharacterMesh('robot_blue');

    // Animation Loop
    animate();

    // Window Resize Handler
    window.addEventListener('resize', onWindowResize);
}

function createCharacterMesh(modelKey) {
    if (activeMesh) scene.remove(activeMesh);

    const data = characterData[modelKey] || characterData['robot_blue'];
    const group = new THREE.Group();

    const mat = new THREE.MeshStandardMaterial({
        color: data.color,
        metalness: 0.6,
        roughness: 0.3,
        emissive: data.color,
        emissiveIntensity: 0.3
    });

    if (data.shape === 'box') {
        // Mecha Beast shape
        const bodyGeo = new THREE.BoxGeometry(1.4, 1.8, 1.2);
        const body = new THREE.Mesh(bodyGeo, mat);
        body.position.y = 1.0;
        body.castShadow = true;
        group.add(body);

        // Eyes
        const eyeMat = new THREE.MeshBasicMaterial({ color: 0xffffff });
        const eyeGeo = new THREE.BoxGeometry(0.8, 0.2, 0.2);
        const eyes = new THREE.Mesh(eyeGeo, eyeMat);
        eyes.position.set(0, 1.4, 0.65);
        group.add(eyes);
    } else if (data.shape === 'skeleton') {
        // Skeleton Warrior shape
        const bodyGeo = new THREE.CylinderGeometry(0.3, 0.4, 1.6, 16);
        const body = new THREE.Mesh(bodyGeo, mat);
        body.position.y = 0.9;
        body.castShadow = true;
        group.add(body);

        const headGeo = new THREE.SphereGeometry(0.35, 16, 16);
        const head = new THREE.Mesh(headGeo, mat);
        head.position.y = 1.9;
        group.add(head);
    } else {
        // Robot Explorer Capsule shape
        const capsGeo = new THREE.CylinderGeometry(0.5, 0.5, 1.4, 32);
        const body = new THREE.Mesh(capsGeo, mat);
        body.position.y = 0.8;
        body.castShadow = true;
        group.add(body);

        const visorMat = new THREE.MeshBasicMaterial({ color: 0xffffff });
        const visorGeo = new THREE.SphereGeometry(0.35, 16, 16);
        const visor = new THREE.Mesh(visorGeo, visorMat);
        visor.position.set(0, 1.2, 0.35);
        group.add(visor);
    }

    activeMesh = group;
    scene.add(activeMesh);
}

function load3DModel(modelKey, displayName, colorHex) {
    createCharacterMesh(modelKey);

    // Update active button state
    document.querySelectorAll('.char-btn').forEach(btn => btn.classList.remove('active'));
    event.currentTarget.classList.add('active');

    // Update overlay text
    const nameLabel = document.getElementById('active-model-name');
    if (nameLabel) nameLabel.textContent = displayName;

    // Update Stats Bars
    const data = characterData[modelKey];
    if (data) {
        document.getElementById('bar-hp').style.width = data.hp;
        document.getElementById('bar-speed').style.width = data.speed;
        document.getElementById('bar-power').style.width = data.power;
    }
}

function animate() {
    requestAnimationFrame(animate);

    if (activeMesh) {
        activeMesh.rotation.y += 0.008;
    }
    if (pedestalMesh) {
        pedestalMesh.rotation.y -= 0.004;
    }

    controls.update();
    renderer.render(scene, camera);
}

function onWindowResize() {
    const canvas = document.getElementById('three-canvas');
    if (!canvas) return;

    const width = canvas.parentElement.clientWidth;
    const height = canvas.parentElement.clientHeight;

    camera.aspect = width / height;
    camera.updateProjectionMatrix();
    renderer.setSize(width, height);
}

// LIGHTBOX & MODAL CONTROLS
function openLightbox(imgSrc) {
    const modal = document.getElementById('lightbox-modal');
    const img = document.getElementById('lightbox-img');
    if (modal && img) {
        img.src = imgSrc;
        modal.classList.add('active');
    }
}

function closeLightbox() {
    const modal = document.getElementById('lightbox-modal');
    if (modal) modal.classList.remove('active');
}

function openGameModal() {
    const modal = document.getElementById('game-modal');
    const iframe = document.getElementById('game-iframe');
    if (iframe) {
        const src = iframe.getAttribute('data-game-src') || '/play/index.html';
        if (!iframe.src || iframe.src === 'about:blank' || iframe.src.endsWith('about:blank')) {
            iframe.src = src;
        }
    }
    if (modal) modal.classList.add('active');
}

function closeGameModal() {
    const modal = document.getElementById('game-modal');
    const iframe = document.getElementById('game-iframe');
    if (modal) modal.classList.remove('active');
    // Liberar WebGL del juego al cerrar
    if (iframe) iframe.src = 'about:blank';
}

// Initialize on DOM load
document.addEventListener('DOMContentLoaded', () => {
    init3DViewport();
});
