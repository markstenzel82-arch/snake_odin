package snake;

import "core:fmt";
import "vendor:sdl2";
import "core:math/rand";

// globals
WINDOW_WIDTH :i32 = 1280
WINDOW_HEIGHT :i32 = 720
BLOCK_SIZE :i32 = 10

main :: proc () {
    running := true;

    sdl2.Init(sdl2.INIT_EVERYTHING);

    window := sdl2.CreateWindow("Snekk Etekk!", sdl2.WINDOWPOS_CENTERED, sdl2.WINDOWPOS_CENTERED, WINDOW_WIDTH, WINDOW_HEIGHT, sdl2.WINDOW_SHOWN);
    game := make_game(BLOCK_SIZE, 200, 0.9, 5);
    defer destroy_game(game);

    // main loop for start menu
    for running {
        run(window, game);
        running = game.running;
    }
}
