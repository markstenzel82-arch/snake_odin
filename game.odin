package snake;

import "core:fmt";
import "vendor:sdl2";
import "core:math/rand";

Direction :: enum {
    UP,
    DOWN,
    LEFT,
    RIGHT
}
OccupiedBy :: enum {
    FRUIT,
    SNAKE
}

Game :: struct {
    snake : ^Snake,
    coords_to_draw : map[[2]i32]OccupiedBy,
    block_size : i32,
    fWidth : i32,
    fHeight : i32,
    fWidthInBlocks : i32,
    fHeightInBlocks : i32,
    score : u32,   
    time_btw_moves : f32,
    tbm_perc_decr : f32,
    fruit_placed : bool,
    running : bool
}

Snake :: struct {
    segments: [dynamic]sdl2.Rect,    
    direction: Direction,
    last_move_time: u32
}

make_game :: proc(block_size : i32, time_btw_moves : f32, tbm_perc_decr : f32, snake_initial_len : i32) -> ^Game {
    // allocate game
    game := new(Game);

    // assign all the rest!
    game.block_size = block_size;
    game.fWidth = WINDOW_WIDTH - (2 * block_size);
    game.fHeight = WINDOW_HEIGHT - (2 * block_size);
    game.fWidthInBlocks = game.fWidth / block_size;
    game.fHeightInBlocks = game.fHeight / block_size;
    game.fruit_placed = false;
    game.running = true;
    game.coords_to_draw = make(map[[2]i32]OccupiedBy);
    game.time_btw_moves = time_btw_moves;
    game.tbm_perc_decr = tbm_perc_decr;

    // make the snake!
    snake := new(Snake);
    snake.segments = make([dynamic]sdl2.Rect);
    snake.direction = .LEFT

    // grow the snake! in the center! to the left!
    center_y :=  (WINDOW_HEIGHT / 2);
    for i : i32 = 0; i < snake_initial_len; i += 1 {
        x := (WINDOW_WIDTH / 2) + (block_size * i);
        append(&snake.segments, sdl2.Rect{x, center_y , block_size, block_size});
        game.coords_to_draw[{x, center_y}] = .SNAKE
    }
    game.snake = snake;
    return game
}

run :: proc(window : ^sdl2.Window, game : ^Game) {   
    last_move_time :u32;

    for game.running {
        draw(window, game);

        if !game.fruit_placed {
            // assuming that a free place for a fruit is found, this is an endless loop. Maybe think about how to do this differently?
            for {
                x := rand.int32_range(1, game.fWidthInBlocks) * game.block_size;
                y := rand.int32_range(1, game.fHeightInBlocks) * game.block_size;

                elem, key_found := game.coords_to_draw[{x, y}];
                if !key_found {
                    game.coords_to_draw[{x, y}] = .FRUIT;
                    game.fruit_placed = true;
                    break;
                }
            }
        }

        event : sdl2.Event;
        for sdl2.PollEvent(&event){
            #partial switch event.type {
                case .QUIT: 
                    game.running = false;
                case .KEYDOWN:            
                    #partial switch event.key.keysym.sym {
                    case .w:
                        if game.snake.direction != .DOWN {
                            game.snake.direction = .UP;
                        }
                    case .s:
                        if game.snake.direction != .UP {
                            game.snake.direction = .DOWN;
                        }
                    case .a:
                        if game.snake.direction != .RIGHT {
                            game.snake.direction = .LEFT;
                        }
                    case .d:
                        if game.snake.direction != .LEFT {
                            game.snake.direction = .RIGHT;
                        }
                }
            }            
        }
        
        current_time := sdl2.GetTicks();
        if (current_time - last_move_time) >= u32(game.time_btw_moves) {
            move_snake(game);
            last_move_time = current_time;
        }        
    }
    fmt.println("GAME OVER, MAN! GAME OVER! OVER! OVER! OVER! OVEr! OVer! Over! over! ove! ov! o!");
}

draw :: proc(window : ^sdl2.Window, game : ^Game) {
    surface := sdl2.GetWindowSurface(window);
    sdl2.FillRect(surface, nil, sdl2.MapRGB(surface.format, 255, 255, 255));
    sdl2.FillRect(surface, &sdl2.Rect{game.block_size, game.block_size, game.fWidth, game.fHeight}, sdl2.MapRGB(surface.format, 0, 0, 0));

    for to_draw, type in game.coords_to_draw {
        bitmap : u32;
        rect := sdl2.Rect{to_draw[0], to_draw[1], game.block_size, game.block_size};
        switch type {
            case .SNAKE:
                bitmap = sdl2.MapRGB(surface.format, 0, 255, 0);
            case .FRUIT:
                bitmap = sdl2.MapRGB(surface.format, 255, 0, 0);
        }
        sdl2.FillRect(surface, &rect, bitmap);
    }
    sdl2.UpdateWindowSurface(window);
}

move_snake :: proc (game : ^Game) {
    remove_tail := true;
    snake := game.snake;
    new_head := snake.segments[0];
    switch snake.direction {
        case .UP:
            new_head.y -= game.block_size;
        case .DOWN:
            new_head.y += game.block_size;
        case .LEFT:
            new_head.x -= game.block_size;
        case .RIGHT:
            new_head.x += game.block_size;
    }

    // check if new head is out of bounds
    if new_head.x < game.block_size || new_head.x >= game.fWidth || new_head.y < game.block_size || new_head.y >= game.fHeight {
        game.running = false;
        return;
    }

    // check if new head would collide with smth
    elem, key_found := game.coords_to_draw[{new_head.x, new_head.y}];
    if key_found {
        switch elem {
            case .SNAKE: {
                // DEADLY COLLISION! ABORT!
                game.running = false;
                return;
            }
            case .FRUIT: {
                // YUM! NOMNOMNOM!
                remove_tail = false;
                game.fruit_placed = false;
                game.time_btw_moves *= game.tbm_perc_decr;
            }
        }
    }
    inject_at(&snake.segments, 0, new_head);
    game.coords_to_draw[{new_head.x, new_head.y}] = .SNAKE;
    
    if remove_tail {
        tail := pop(&snake.segments);
        delete_key(&game.coords_to_draw, [2]i32{tail.x, tail.y});
    }

}

destroy_game :: proc(game: ^Game) {    
    delete(game.snake.segments);
    free(game.snake);
    delete(game.coords_to_draw);

    free(game);

}