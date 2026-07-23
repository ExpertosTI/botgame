/* CHADRINE landing — hangar con GLB reales del roster */

const ROSTER = [
  { id: "blocky_a", name: "Blocky A", file: "/media/roster/blocky_a.glb", thumb: "/media/roster/Textures/texture-a.png", scale: 1.15 },
  { id: "blocky_b", name: "Blocky B", file: "/media/roster/blocky_b.glb", thumb: "/media/roster/Textures/texture-b.png", scale: 1.15 },
  { id: "kay_knight", name: "Caballero", file: "/media/roster/kay_knight.glb", thumb: "/media/ui/robot_verde.png", scale: 1.0 },
  { id: "kay_mage", name: "Mago", file: "/media/roster/kay_mage.glb", thumb: "/media/ui/robot_amarillo.png", scale: 1.0 },
  { id: "kay_barbarian", name: "Bárbaro", file: "/media/roster/kay_barbarian.glb", thumb: "/media/ui/robot_azul.png", scale: 1.0 },
  { id: "forest_archer", name: "Arquero", file: "/media/roster/forest_archer.glb", thumb: "/media/roster/Textures/colormap.png", scale: 1.05 },
  { id: "skel_warrior", name: "Esqueleto", file: "/media/roster/skel_warrior.glb", thumb: "/media/ui/beast_classic.png", scale: 1.1 },
  { id: "skel_mage", name: "Skel Mago", file: "/media/roster/skel_mage.glb", thumb: "/media/ui/beast_shadow.png", scale: 1.1 },
];

const loadingIds = new Set();

const MAPS = [
  { id: "lab_neon", name: "Laboratorio Neon", src: "/media/maps/map_neon.jpg" },
  { id: "containers", name: "Contenedores", src: "/media/maps/map_containers.jpg" },
  { id: "ruins", name: "Ruinas", src: "/media/maps/map_ruins.jpg" },
];

let scene, camera, renderer, controls, gltfLoader;
let activeRoot = null;
let pedestal = null;
let currentId = ROSTER[0].id;
const modelCache = {};

function init() {
  buildRosterUI();
  buildMapsUI();
  initThree();
  loadModel(ROSTER[0].id);
  wireVideo();
  window.addEventListener("resize", onResize);
}

function buildRosterUI() {
  const host = document.getElementById("roster-btns");
  if (!host) return;
  host.innerHTML = "";
  ROSTER.forEach((c, i) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "roster-btn" + (i === 0 ? " active" : "");
    btn.setAttribute("role", "option");
    btn.dataset.id = c.id;
    btn.innerHTML = `<img src="${c.thumb}" alt="" loading="lazy" onerror="this.style.opacity=0.3"><span>${c.name}</span>`;
    btn.addEventListener("click", () => {
      host.querySelectorAll(".roster-btn").forEach((b) => b.classList.remove("active"));
      btn.classList.add("active");
      loadModel(c.id);
    });
    host.appendChild(btn);
  });
}

function buildMapsUI() {
  const row = document.getElementById("map-row");
  if (!row) return;
  row.innerHTML = "";
  MAPS.forEach((m) => {
    const fig = document.createElement("figure");
    fig.className = "map-card";
    fig.innerHTML = `<img src="${m.src}" alt="${m.name}" loading="lazy"><figcaption>${m.name}</figcaption>`;
    row.appendChild(fig);
  });
}

function initThree() {
  const canvas = document.getElementById("three-canvas");
  if (!canvas || typeof THREE === "undefined") return;

  const wrap = canvas.parentElement;
  const w = wrap.clientWidth || 640;
  const h = Math.max(wrap.clientHeight - 88, 280);

  scene = new THREE.Scene();
  scene.fog = new THREE.FogExp2(0x060a0e, 0.045);

  camera = new THREE.PerspectiveCamera(40, w / h, 0.1, 100);
  camera.position.set(2.4, 1.8, 4.2);

  renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
  renderer.setSize(w, h);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.outputEncoding = THREE.sRGBEncoding;
  renderer.setClearColor(0x000000, 0);

  controls = new THREE.OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  controls.target.set(0, 0.95, 0);
  controls.minDistance = 2.2;
  controls.maxDistance = 7;
  controls.maxPolarAngle = Math.PI * 0.49;

  scene.add(new THREE.AmbientLight(0x6a8a92, 0.85));
  const key = new THREE.DirectionalLight(0xffffff, 1.35);
  key.position.set(4, 8, 5);
  scene.add(key);
  const fill = new THREE.PointLight(0x1ad4c0, 2.2, 12);
  fill.position.set(-3, 2.2, 2);
  scene.add(fill);
  const rim = new THREE.PointLight(0xe8a23a, 1.4, 10);
  rim.position.set(2.5, 1.5, -2.5);
  scene.add(rim);

  const grid = new THREE.GridHelper(14, 14, 0x1ad4c0, 0x142028);
  grid.position.y = 0;
  scene.add(grid);

  const pedGeo = new THREE.CylinderGeometry(1.25, 1.4, 0.22, 48);
  const pedMat = new THREE.MeshStandardMaterial({
    color: 0x0c1820,
    metalness: 0.85,
    roughness: 0.25,
    emissive: 0x0a3d38,
    emissiveIntensity: 0.45,
  });
  pedestal = new THREE.Mesh(pedGeo, pedMat);
  pedestal.position.y = -0.11;
  scene.add(pedestal);

  const manager = new THREE.LoadingManager();
  manager.setURLModifier((url) => {
    // Blocky/forest GLBs referencian Textures/*.png relativos al GLB
    if (url.indexOf("Textures/") !== -1 || /texture-[a-f]\.png|colormap\.png/i.test(url)) {
      const name = url.split("/").pop();
      return "/media/roster/Textures/" + name;
    }
    return url;
  });
  gltfLoader = new THREE.GLTFLoader(manager);
  animate();
}

function clearActive() {
  if (!activeRoot || !scene) return;
  scene.remove(activeRoot);
  activeRoot.traverse((n) => {
    if (n.isMesh) {
      n.geometry && n.geometry.dispose();
      if (n.material) {
        if (Array.isArray(n.material)) n.material.forEach((m) => m.dispose());
        else n.material.dispose();
      }
    }
  });
  activeRoot = null;
}

function fitModel(root, scaleMult) {
  const box = new THREE.Box3().setFromObject(root);
  const size = box.getSize(new THREE.Vector3());
  const center = box.getCenter(new THREE.Vector3());
  const maxDim = Math.max(size.x, size.y, size.z) || 1;
  const target = 2.0 * (scaleMult || 1);
  const s = target / maxDim;
  root.scale.setScalar(s);
  root.position.sub(center.multiplyScalar(s));
  root.position.y = -box.min.y * s + 0.02;
}

function loadModel(id) {
  const entry = ROSTER.find((r) => r.id === id) || ROSTER[0];
  currentId = entry.id;
  const nameEl = document.getElementById("model-name");
  if (nameEl) nameEl.textContent = entry.name;

  if (!gltfLoader) return;

  const apply = (root) => {
    if (currentId !== entry.id) return;
    clearActive();
    activeRoot = root.clone(true);
    fitModel(activeRoot, entry.scale);
    scene.add(activeRoot);
  };

  if (modelCache[entry.id]) {
    apply(modelCache[entry.id]);
    return;
  }
  if (loadingIds.has(entry.id)) return;
  loadingIds.add(entry.id);

  gltfLoader.load(
    entry.file,
    (gltf) => {
      loadingIds.delete(entry.id);
      modelCache[entry.id] = gltf.scene;
      apply(gltf.scene);
    },
    undefined,
    (err) => {
      loadingIds.delete(entry.id);
      console.warn("GLB load failed", entry.file, err);
      if (currentId !== entry.id) return;
      clearActive();
      const g = new THREE.Group();
      const mat = new THREE.MeshStandardMaterial({ color: 0x1ad4c0, metalness: 0.4, roughness: 0.4 });
      const mesh = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 0.4, 1.4, 16), mat);
      mesh.position.y = 0.9;
      g.add(mesh);
      activeRoot = g;
      scene.add(g);
    }
  );
}

function animate() {
  requestAnimationFrame(animate);
  if (activeRoot) activeRoot.rotation.y += 0.006;
  if (pedestal) pedestal.rotation.y -= 0.003;
  if (controls) controls.update();
  if (renderer && scene && camera) renderer.render(scene, camera);
}

function onResize() {
  const canvas = document.getElementById("three-canvas");
  if (!canvas || !renderer || !camera) return;
  const wrap = canvas.parentElement;
  const w = wrap.clientWidth || 640;
  const h = Math.max(wrap.clientHeight - 88, 280);
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
  renderer.setSize(w, h);
}

function wireVideo() {
  const vid = document.getElementById("intro-video");
  const btn = document.getElementById("btn-unmute");
  if (!vid) return;
  vid.play().catch(() => {});
  if (btn) {
    btn.addEventListener("click", () => {
      vid.muted = !vid.muted;
      if (!vid.muted) vid.play().catch(() => {});
      btn.textContent = vid.muted ? "Sonido del trailer" : "Silenciar trailer";
    });
  }
}

document.addEventListener("DOMContentLoaded", init);
