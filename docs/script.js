const text_decoder = new TextDecoder();
let console_log_buffer = "";

let sw = {
    instance: undefined,

    screen: {
        canvas: undefined,
        ctx2D: undefined,
        width: undefined,
        height: undefined,
    },

    init: function (obj) {
        this.instance = obj.instance;

        // canvas
        this.screen.width = this.getGlobal("screen_width");
        this.screen.height = this.getGlobal("screen_height");

        this.screen.canvas = document.getElementById("canvas");
        this.screen.canvas.width = this.screen.width;
        this.screen.canvas.height = this.screen.height;
        this.screen.ctx2D = this.screen.canvas.getContext("2d");
        this.screen.ctx2D.fillStyle = "#ffffff";
        this.screen.ctx2D.clearRect(0, 0, 550, 550);
    },
    getString: function (ptr, len) {
        const memory = this.instance.exports.memory;
        return text_decoder.decode(new Uint8Array(memory.buffer, ptr, len));
    },
    getGlobal: function (global_name) {
        const exports = this.instance.exports;
        const global_ptr = exports[global_name].value;
        const memory = this.instance.exports.memory;
        const u32bytes = new Uint8Array(memory.buffer, global_ptr, 4);
        return (u32bytes[3] << 24) | (u32bytes[2] << 16) | (u32bytes[1] << 8) | u32bytes[0];
    },
};

let importObject = {
    env: {
        jsConsoleLogWrite: function (ptr, len) {
            console_log_buffer += sw.getString(ptr, len);
        },
        jsConsoleLogFlush: function () {
            console.log(console_log_buffer);
            console_log_buffer = "";
        },
        jsCanvas2DClear: function () {
            sw.screen.ctx2D.clearRect(0, 0, sw.screen.width, sw.screen.height);
        },
        jsCanvas2DFillRect: function (x, y, width, height) {
            sw.screen.ctx2D.fillRect(x, y, width, height);
        },
    },
};

let canvas;

async function bootstrap() {
    sw.init(await WebAssembly.instantiateStreaming(fetch("./space.wasm"), importObject));

    const init = sw.instance.exports.init;
    const frame = sw.instance.exports.frame;
    const step = sw.instance.exports.step;

    const handleKeyDown = sw.instance.exports.handleKeyDown;
    const handleKeyUp = sw.instance.exports.handleKeyUp;
    document.addEventListener("keydown", (e) => {
        const key = e.key ? e.key.charCodeAt(0) : 0;
        handleKeyDown(key);
    });
    document.addEventListener("keyup", (e) => {
        const key = e.key ? e.key.charCodeAt(0) : 0;
        handleKeyUp(key);
    });

    init();
    // for (let i = 0; i < 10000; i += 1) {
    //     step();
    // }
    setInterval(frame, 56);
}

bootstrap();
