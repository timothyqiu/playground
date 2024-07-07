import "./style.css";

const EPS = 1e-6;
const Z_NEAR = 1.0;
const Z_FAR = 10.0;
const FOV = Math.PI * 0.5;
const SCREEN_WIDTH = 256;
const PLAYER_STEP_LEN = 0.5;

class Vector2 {
    x: number;
    y: number;
    constructor(x: number, y: number) {
        this.x = x;
        this.y = y;
    }
    static zero(): Vector2 {
        return new Vector2(0, 0);
    }
    static fromAngle(angle: number): Vector2 {
        return new Vector2(Math.cos(angle), Math.sin(angle));
    }
    add(that: Vector2): Vector2 {
        return new Vector2(this.x + that.x, this.y + that.y);
    }
    sub(that: Vector2): Vector2 {
        return new Vector2(this.x - that.x, this.y - that.y);
    }
    div(that: Vector2): Vector2 {
        return new Vector2(this.x / that.x, this.y / that.y);
    }
    mul(that: Vector2): Vector2 {
        return new Vector2(this.x * that.x, this.y * that.y);
    }
    length(): number {
        return Math.sqrt(this.x * this.x + this.y * this.y);
    }
    sqrLength(): number {
        return this.x * this.x + this.y * this.y;
    }
    norm(): Vector2 {
        const l = this.length();
        if (l === 0) return new Vector2(0, 0);
        return new Vector2(this.x / l, this.y / l);
    }
    scale(value: number): Vector2 {
        return new Vector2(this.x * value, this.y * value);
    }
    distanceTo(that: Vector2): number {
        return that.sub(this).length();
    }
    sqrDistanceTo(that: Vector2): number {
        return that.sub(this).sqrLength();
    }
    angle(): number {
        return Math.atan2(this.y, this.x);
    }
    array(): [number, number] {
        return [this.x, this.y];
    }
    lerp(that: Vector2, t: number): Vector2 {
        return that.sub(this).scale(t).add(this);
    }
    dot(that: Vector2): number {
        return this.x * that.x + this.y * that.y;
    }
}

function canvasSize(ctx: CanvasRenderingContext2D): Vector2 {
    return new Vector2(ctx.canvas.width, ctx.canvas.height);
}

function fillCircle(ctx: CanvasRenderingContext2D, center: Vector2, radius: number) {
    ctx.beginPath();
    ctx.arc(...center.array(), radius, 0, 2 * Math.PI);
    ctx.fill();
}

function strokeLine(ctx: CanvasRenderingContext2D, p1: Vector2, p2: Vector2) {
    ctx.beginPath();
    ctx.moveTo(...p1.array());
    ctx.lineTo(...p2.array());
    ctx.stroke();
}

function snap(x: number, dx: number): number {
    if (dx > 0) return Math.ceil(x + EPS);
    if (dx < 0) return Math.floor(x - EPS);
    return x;
}

function hittingCell(p1: Vector2, p2: Vector2): Vector2 {
    const d = p2.sub(p1);
    return new Vector2(Math.floor(p2.x + Math.sign(d.x) * EPS),
        Math.floor(p2.y + Math.sign(d.y) * EPS));
}

function rayStep(p1: Vector2, p2: Vector2): Vector2 {
    // p1 = (x1, y1)
    // p2 = (x2, y2)
    //
    // | y1 = k * x1 + c
    // | y2 = k * x2 + c
    //
    // c = y1 - k * x1
    // k = (y2 - y1) / (x2 - x1)
    const d = p2.sub(p1);
    let p3 = p2;
    if (d.x !== 0) {
        const k = (p2.y - p1.y) / (p2.x - p1.x);
        const c = p1.y - k * p1.x;

        {
            const x3 = snap(p2.x, d.x);
            const y3 = x3 * k + c;
            p3 = new Vector2(x3, y3);
        }

        if (k !== 0) {
            const y3 = snap(p2.y, d.y);
            const x3 = (y3 - c) / k;
            const p3t = new Vector2(x3, y3);
            if (p2.sqrDistanceTo(p3t) < p2.sqrDistanceTo(p3)) {
                p3 = p3t;
            }
        }
    } else {
        p3 = new Vector2(p2.x, snap(p2.y, d.y));
    }
    return p3;
}

function castRay(scene: Scene, p1: Vector2, p2: Vector2): Vector2 {
    const start = p1;
    while (start.distanceTo(p1) < Z_FAR) {
        const c = hittingCell(p1, p2);
        if (insideScene(scene, c) && scene[c.y][c.x] !== null) {
            break;
        }

        const p3 = rayStep(p1, p2);
        p1 = p2;
        p2 = p3;
    }
    return p2;
}

type Scene = Array<Array<string | null>>;

function insideScene(scene: Scene, p: Vector2): boolean {
    const size = sceneSize(scene);
    return 0 <= p.x && p.x < size.x && 0 <= p.y && p.y < size.y;
}

function sceneSize(scene: Scene): Vector2 {
    const y = scene.length;
    if (y === 0) {
        return new Vector2(0, 0);
    }
    return new Vector2(scene[0].length, y);
}

class Player {
    position: Vector2;
    direction: number;
    constructor(position: Vector2, direction: number) {
        this.position = position;
        this.direction = direction;
    }
    fovRange(): [Vector2, Vector2] {
        const side = Z_NEAR / Math.cos(FOV * 0.5);
        const l = this.position.add(Vector2.fromAngle(this.direction - FOV * 0.5).scale(side));
        const r = this.position.add(Vector2.fromAngle(this.direction + FOV * 0.5).scale(side));
        return [l, r];
    }
}

function renderMinimap(ctx: CanvasRenderingContext2D, player: Player, position: Vector2, size: Vector2, scene: Scene) {
    ctx.save();

    const gridSize = sceneSize(scene);

    ctx.translate(...position.array());
    ctx.scale(...size.div(gridSize).array());

    ctx.fillStyle = "#18181877";
    ctx.fillRect(0, 0, gridSize.x, gridSize.y);

    for (let y = 0; y < gridSize.y; y++) {
        for (let x = 0; x < gridSize.x; x++) {
            const color = scene[y][x];
            if (color !== null) {
                ctx.fillStyle = color;
                ctx.fillRect(x, y, 1, 1);
            }
        }
    }

    ctx.strokeStyle = "#303030";
    ctx.lineWidth = 0.04;
    for (let x = 0; x <= gridSize.x; x++) {
        strokeLine(ctx, new Vector2(x, 0), new Vector2(x, gridSize.y));
    }
    for (let y = 0; y <= gridSize.y; y++) {
        strokeLine(ctx, new Vector2(0, y), new Vector2(gridSize.x, y));
    }

    ctx.fillStyle = "magenta";
    fillCircle(ctx, player.position, 0.2);

    ctx.strokeStyle = "magenta";
    const [p1, p2] = player.fovRange();
    strokeLine(ctx, player.position, p1);
    strokeLine(ctx, player.position, p2);
    strokeLine(ctx, p1, p2);

    ctx.restore();
}

function renderScene(ctx: CanvasRenderingContext2D, player: Player, scene: Scene) {
    const stripWidth = Math.ceil(ctx.canvas.width / SCREEN_WIDTH);
    const [r1, r2] = player.fovRange();
    const camera_dir = Vector2.fromAngle(player.direction);
    for (let x = 0; x < SCREEN_WIDTH; x++) {
        const p = castRay(scene, player.position, r1.lerp(r2, x / SCREEN_WIDTH));
        const c = hittingCell(player.position, p);
        if (insideScene(scene, c)) {
            const color = scene[c.y][c.x];
            if (color != null) {
                const distance = p.sub(player.position).dot(camera_dir);
                if (distance >= 0) {
                    const stripHeight = ctx.canvas.height / distance;
                    ctx.fillStyle = color;
                    ctx.fillRect(x * stripWidth, (ctx.canvas.height - stripHeight) / 2, stripWidth, stripHeight);
                }
            }
        }
    }
}

function renderGame(ctx: CanvasRenderingContext2D, player: Player, scene: Scene) {
    let minimapPosition = canvasSize(ctx).scale(0.03);
    let cellSize = ctx.canvas.width * 0.03;
    let minimapSize = sceneSize(scene).scale(cellSize);

    ctx.fillStyle = "#181818";
    ctx.fillRect(0, 0, ctx.canvas.width, ctx.canvas.height);
    renderScene(ctx, player, scene);
    renderMinimap(ctx, player, minimapPosition, minimapSize, scene);
}

function save(player: Player) {
    localStorage.setItem("player", JSON.stringify(player));
}

function load(): Player | null {
    const saved = localStorage.getItem("player");
    if (saved === null) return null;
    const parsed = JSON.parse(saved);
    if ("position" in parsed && "direction" in parsed) {
        return new Player(new Vector2(parsed.position.x, parsed.position.y), parsed.direction);
    }
    return null;
}

const game = document.getElementById("game") as (HTMLCanvasElement | null);
if (game === null) {
    throw new Error("No canvas with id `game` is found");
}
game.width = 800;
game.height = 600;

const ctx = game.getContext("2d", {});
if (ctx === null) {
    throw new Error("2D context is not supported");
}

const scene = [
    [null, null, "cyan", "yellow", null, null, null, null, null],
    [null, null, null, "maroon", null, null, null, null, null],
    [null, "red", "green", "blue", null, null, null, "purple", "olive"],
    [null, null, null, null, null, null, null, null, null],
    [null, null, null, null, null, null, null, null, null],
    [null, null, null, null, null, null, null, null, null],
    [null, null, null, null, null, null, null, null, null],
];
const player = load() ?? new Player(sceneSize(scene).mul(new Vector2(0.63, 0.63)), -2.2);

window.addEventListener("keydown", (event) => {
    if (event.repeat) return;
    switch (event.code) {
        case "KeyW": {
            player.position = player.position.add(Vector2.fromAngle(player.direction).scale(PLAYER_STEP_LEN));
            save(player);
            renderGame(ctx, player, scene);
        } break;
        case "KeyS": {
            player.position = player.position.sub(Vector2.fromAngle(player.direction).scale(PLAYER_STEP_LEN));
            renderGame(ctx, player, scene);
            save(player);
        } break;
        case "KeyD": {
            player.direction += Math.PI * 0.1;
            renderGame(ctx, player, scene);
            save(player);
        } break;
        case "KeyA": {
            player.direction -= Math.PI * 0.1;
            renderGame(ctx, player, scene);
            save(player);
        } break;
    }
});

renderGame(ctx, player, scene);
