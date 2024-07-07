import "./style.css";

class Vector2 {
    x: number;
    y: number;
    constructor(x: number, y: number) {
        this.x = x;
        this.y = y;
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
    norm(): Vector2 {
        const l = this.length();
        if (l == 0) return new Vector2(0, 0);
        return new Vector2(this.x / l, this.y / l);
    }
    scale(value: number): Vector2 {
        return new Vector2(this.x * value, this.y * value);
    }
    distanceTo(that: Vector2): number {
        return that.sub(this).length();
    }
    array(): [number, number] {
        return [this.x, this.y];
    }
};

const EPS = 1e-3;
const GRID_ROWS = 10;
const GRID_COLS = 10;
const GRID_SIZE = new Vector2(GRID_COLS, GRID_ROWS);

let scene = Array.from(Array(GRID_ROWS), () => Array(GRID_COLS).fill(0));

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
            if (p2.distanceTo(p3t) < p2.distanceTo(p3)) {
                p3 = p3t;
            }
        }
    } else {
        p3 = new Vector2(p2.x, snap(p2.y, d.y));
    }
    return p3;
}

function minimap(ctx: CanvasRenderingContext2D, p2: Vector2 | undefined) {
    ctx.reset();

    ctx.fillStyle = "#181818";
    ctx.fillRect(0, 0, ctx.canvas.width, ctx.canvas.height);
    ctx.scale(ctx.canvas.width / GRID_COLS, ctx.canvas.height / GRID_ROWS);

    for (let y = 0; y < GRID_ROWS; y++) {
        for (let x = 0; x < GRID_COLS; x++) {
            if (scene[y][x] !== 0) {
                ctx.fillStyle = "#303030";
                ctx.fillRect(x, y, 1, 1);
            }
        }
    }

    ctx.strokeStyle = "#303030";
    ctx.lineWidth = 0.02;
    for (let x = 0; x <= GRID_COLS; x++) {
        strokeLine(ctx, new Vector2(x, 0), new Vector2(x, GRID_ROWS));
    }
    for (let y = 0; y <= GRID_ROWS; y++) {
        strokeLine(ctx, new Vector2(0, y), new Vector2(GRID_COLS, y));
    }

    let p1 = new Vector2(GRID_COLS * 0.43, GRID_ROWS * 0.33);
    ctx.fillStyle = "magenta";
    fillCircle(ctx, p1, 0.2);
    if (p2 === undefined) {
        return;
    }

    for (; ;) {
        const c = hittingCell(p1, p2);
        if (c.x < 0 || c.x >= GRID_SIZE.x ||
            c.y < 0 || c.y >= GRID_SIZE.y ||
            scene[c.y][c.x] === 1
        ) {
            break;
        }

        fillCircle(ctx, p2, 0.2);
        ctx.strokeStyle = "magenta";
        strokeLine(ctx, p1, p2);
        const p3 = rayStep(p1, p2);
        fillCircle(ctx, p3, 0.2);
        strokeLine(ctx, p2, p3);

        p1 = p2;
        p2 = p3;
    }
}

scene[1][1] = 1;

const game = document.getElementById("game") as (HTMLCanvasElement | null);
if (game === null) {
    throw new Error("No canvas with id `game` is found");
}
game.width = 800;
game.height = 800;

const ctx = game.getContext("2d", {});
if (ctx === null) {
    throw new Error("2D context is not supported");
}

let p2: Vector2 | undefined = undefined;
game.addEventListener("mousemove", (event) => {
    p2 = new Vector2(event.offsetX, event.offsetY)
        .div(canvasSize(ctx))
        .mul(GRID_SIZE);
    minimap(ctx, p2);
});
minimap(ctx, p2);
