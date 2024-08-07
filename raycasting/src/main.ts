import "./style.css";

const EPS = 1e-6;
const Z_NEAR = 0.1;
const Z_FAR = 10.0;
const FOV = Math.PI * 0.5;
const SCREEN_WIDTH = 240;
const PLAYER_SPEED = 2.0;
const PLAYER_SIZE = 0.5;

class RGBA {
    r: number;
    g: number;
    b: number;
    a: number;
    constructor(r: number, g: number, b: number, a: number) {
        this.r = r;
        this.g = g;
        this.b = b;
        this.a = a;
    }
    static red = () => new RGBA(1, 0, 0, 1)
    static green = () => new RGBA(0, 1, 0, 1)
    static blue = () => new RGBA(0, 0, 1, 1)
    static magenta = () => new RGBA(1, 0, 1, 1)
    static cyan = () => new RGBA(0, 1, 1, 1)
    static yellow = () => new RGBA(1, 1, 0, 1)
    static olive = () => new RGBA(0.5, 0.5, 0, 1)
    static maroon = () => new RGBA(0.5, 0, 0, 1)
    static purple = () => new RGBA(0.5, 0, 0.5, 1)
    brightness(factor: number): RGBA {
        return new RGBA(
            this.r * factor,
            this.g * factor,
            this.b * factor,
            this.a
        );
    }
    toStyle(): string {
        return `rgba(` +
            `${Math.floor(this.r * 255)}, ` +
            `${Math.floor(this.g * 255)}, ` +
            `${Math.floor(this.b * 255)}, ` +
            `${this.a})`;
    }
}

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
    static fromScalar(value: number): Vector2 {
        return new Vector2(value, value);
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
    map(f: (x: number) => number): Vector2 {
        return new Vector2(f(this.x), f(this.y));
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
        const cell = scene.getWall(c);
        if (cell !== undefined && cell !== null) {
            break;
        }

        const p3 = rayStep(p1, p2);
        p1 = p2;
        p2 = p3;
    }
    return p2;
}

type Tile = RGBA | HTMLImageElement | null;

class Scene {
    walls: Array<Tile>;
    width: number;
    height: number;
    constructor(walls: Array<Array<Tile>>) {
        this.height = walls.length;
        this.width = Number.MIN_VALUE;
        for (let row of walls) {
            this.width = Math.max(this.width, row.length);
        }
        this.walls = [];
        for (let row of walls) {
            this.walls = this.walls.concat(row);
            for (let i = 0; i < this.width - row.length; i++) {
                this.walls.push(null);
            }
        }
    }
    size(): Vector2 {
        return new Vector2(this.width, this.height);
    }
    contains(p: Vector2): boolean {
        return 0 <= p.x && p.x < this.width && 0 <= p.y && p.y < this.height;
    }
    getWall(p: Vector2): Tile | undefined {
        if (!this.contains(p)) return undefined;
        const fp = p.map(Math.floor);
        return this.walls[fp.y * this.width + fp.x];
    }
    isWall(p: Vector2): boolean {
        const c = this.getWall(p);
        return c !== null && c !== undefined;
    }
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

    const gridSize = scene.size();

    ctx.translate(...position.array());
    ctx.scale(...size.div(gridSize).array());

    ctx.fillStyle = "#18181877";
    ctx.fillRect(0, 0, gridSize.x, gridSize.y);

    for (let y = 0; y < gridSize.y; y++) {
        for (let x = 0; x < gridSize.x; x++) {
            const cell = scene.getWall(new Vector2(x, y));
            if (cell instanceof RGBA) {
                ctx.fillStyle = cell.toStyle();
                ctx.fillRect(x, y, 1, 1);
            } else if (cell instanceof HTMLImageElement) {
                ctx.drawImage(cell, x, y, 1, 1);
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
    ctx.fillRect(
        player.position.x - PLAYER_SIZE * 0.5,
        player.position.y - PLAYER_SIZE * 0.5,
        PLAYER_SIZE, PLAYER_SIZE);

    ctx.strokeStyle = "magenta";
    const [p1, p2] = player.fovRange();
    strokeLine(ctx, player.position, p1);
    strokeLine(ctx, player.position, p2);
    strokeLine(ctx, p1, p2);

    ctx.restore();
}

function renderWalls(ctx: CanvasRenderingContext2D, player: Player, scene: Scene) {
    const stripWidth = Math.ceil(ctx.canvas.width / SCREEN_WIDTH);
    const [r1, r2] = player.fovRange();
    const camera_dir = Vector2.fromAngle(player.direction);
    for (let x = 0; x < SCREEN_WIDTH; x++) {
        const p = castRay(scene, player.position, r1.lerp(r2, x / SCREEN_WIDTH));
        const c = hittingCell(player.position, p);
        const cell = scene.getWall(c);
        if (cell === null || cell === undefined) {
            continue;
        }
        const distance = p.sub(player.position).dot(camera_dir);
        if (distance < 0) {
            continue;
        }
        const stripHeight = ctx.canvas.height / distance;

        if (cell instanceof RGBA) {
            ctx.fillStyle = cell.brightness(1 / distance).toStyle();
            ctx.fillRect(x * stripWidth, (ctx.canvas.height - stripHeight) / 2, stripWidth, stripHeight);
        }
        if (cell instanceof HTMLImageElement) {
            const t = p.sub(c);
            const u = (Math.abs(t.x - 1) < EPS) || (Math.abs(t.x) < EPS) ? t.y : t.x;

            ctx.drawImage(
                cell,
                Math.floor(u * cell.width), 0, 1, cell.height,
                x * stripWidth, (ctx.canvas.height - stripHeight) / 2, stripWidth, stripHeight
            );

            ctx.fillStyle = new RGBA(0.05, 0.05, 0.05, (distance - 3) / 3).toStyle();
            const top = Math.floor((ctx.canvas.height - stripHeight) / 2);
            const bottom = Math.ceil((ctx.canvas.height - stripHeight) / 2 + stripHeight);
            ctx.fillRect(x * stripWidth, top, stripWidth, bottom - top);
        }
    }
}

function renderGame(ctx: CanvasRenderingContext2D, player: Player, scene: Scene) {
    let minimapPosition = canvasSize(ctx).scale(0.03);
    let cellSize = ctx.canvas.width * 0.03;
    let minimapSize = scene.size().scale(cellSize);

    ctx.fillStyle = "#181818";
    ctx.fillRect(0, 0, ctx.canvas.width, ctx.canvas.height);
    ctx.fillStyle = "hsl(220, 20%, 30%)";
    ctx.fillRect(0, 0, ctx.canvas.width, ctx.canvas.height / 2);

    renderWalls(ctx, player, scene);
    renderMinimap(ctx, player, minimapPosition, minimapSize, scene);
}

async function loadImageData(url: string): Promise<HTMLImageElement> {
    const image = new Image();
    image.src = url;
    return new Promise((resolve, reject) => {
        image.onload = () => {
            resolve(image);
        };
        image.onerror = reject;
    });
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

function canPlayerGoThere(scene: Scene, newPosition: Vector2): boolean {
    const topLeftCorner = newPosition.sub(Vector2.fromScalar(PLAYER_SIZE * 0.5)).map(Math.floor);
    const bottomRightCorner = newPosition.add(Vector2.fromScalar(PLAYER_SIZE * 0.5)).map(Math.floor);
    for (let x = topLeftCorner.x; x <= bottomRightCorner.x; x++) {
        for (let y = topLeftCorner.y; y < bottomRightCorner.y; y++) {
            if (scene.isWall(new Vector2(x, y))) {
                return false;
            }
        }
    }
    return true;
}

(async () => {
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
    ctx.imageSmoothingEnabled = false;

    const exit = await loadImageData("exit.png").catch(() => RGBA.magenta());
    const wall = await loadImageData("wall.png").catch(() => RGBA.magenta());
    const tech_wall = await loadImageData("tech-wall.png").catch(() => RGBA.magenta());

    const scene = new Scene([
        [null, null, tech_wall, tech_wall, null, null, null, null, wall],
        [null, null, null, tech_wall, null, null, null, null, null],
        [null, tech_wall, exit, tech_wall, null, null, null, wall, wall],
        [null, null, null, null, null, null, null, null, null],
        [null, null, null, null, null, null, null, null, null],
        [wall, null, null, null, null, null, null, null, null],
        [wall, null, null, null, null, null, null, null, null],
    ]);
    const player = load() ?? new Player(scene.size().mul(new Vector2(0.63, 0.63)), -2.2);

    let movingForward = false;
    let movingBackward = false;
    let turningLeft = false;
    let turningRight = false;

    window.addEventListener("keydown", (event) => {
        if (event.repeat) return;
        switch (event.code) {
            case "KeyW": movingForward = true; break;
            case "KeyS": movingBackward = true; break;
            case "KeyA": turningLeft = true; break;
            case "KeyD": turningRight = true; break;
        }
    });
    window.addEventListener("keyup", (event) => {
        if (event.repeat) return;
        switch (event.code) {
            case "KeyW": movingForward = false; break;
            case "KeyS": movingBackward = false; break;
            case "KeyA": turningLeft = false; break;
            case "KeyD": turningRight = false; break;
        }
    });

    let prevTimestamp = performance.now();
    const frame = (timestamp: number) => {
        const deltaTime = (timestamp - prevTimestamp) / 1000;

        let velocity = Vector2.zero();
        let angularVelocity = 0.0;

        if (movingForward) {
            velocity = velocity.add(Vector2.fromAngle(player.direction).scale(PLAYER_SPEED));
        }
        if (movingBackward) {
            velocity = velocity.sub(Vector2.fromAngle(player.direction).scale(PLAYER_SPEED));
        }
        if (turningLeft) {
            angularVelocity -= Math.PI * 0.4;
        }
        if (turningRight) {
            angularVelocity += Math.PI * 0.4;
        }

        let playerUpdated = angularVelocity !== 0;
        player.direction += angularVelocity * deltaTime;

        const nx = player.position.x + velocity.x * deltaTime;
        if (canPlayerGoThere(scene, new Vector2(nx, player.position.y))) {
            player.position.x = nx;
            playerUpdated = true;
        }
        const ny = player.position.y + velocity.y * deltaTime;
        if (canPlayerGoThere(scene, new Vector2(player.position.x, ny))) {
            player.position.y = ny;
            playerUpdated = true;
        }

        if (playerUpdated) {
            save(player);
        }

        prevTimestamp = timestamp;
        renderGame(ctx, player, scene);
        window.requestAnimationFrame(frame);
    }
    window.requestAnimationFrame(frame);
})();
