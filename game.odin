package snake;

import "core:fmt";
import "core:os";
import "vendor:sdl2";
import "core:math/rand";

Direction :: enum {
    UP,
    DOWN,
    LEFT,
    RIGHT    
}
DrawableType :: enum {
    FRUIT,
    SNAKE
}
Bitmaps :: struct {
    body_v : ^sdl2.Surface,
    body_h : ^sdl2.Surface,
    head_l : ^sdl2.Surface,
    head_r : ^sdl2.Surface,
    head_d : ^sdl2.Surface,
    head_u : ^sdl2.Surface,
    tail_d : ^sdl2.Surface,
    tail_l : ^sdl2.Surface,
    tail_r : ^sdl2.Surface,
    tail_u : ^sdl2.Surface,
    turn_d_l : ^sdl2.Surface,
    turn_d_r : ^sdl2.Surface,
    turn_u_l : ^sdl2.Surface,
    turn_u_r : ^sdl2.Surface,
    chili : ^sdl2.Surface
}

Game :: struct {
    snake : ^Snake,
    bitmaps : ^Bitmaps,
    coords_to_draw : map[[2]i32]Drawable,        
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
    segments: [dynamic]Segment,
    direction: Direction,
    last_direction: Direction,
    next_direction: Direction,
    last_move_time: u32
}
Segment :: struct {
    drawable: Drawable,
    direction: Direction
}

Drawable :: struct {
    rect: sdl2.Rect,
    bitmap: ^sdl2.Surface,
    type: DrawableType,    
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
    game.coords_to_draw = make(map[[2]i32]Drawable);
    game.time_btw_moves = time_btw_moves;
    game.tbm_perc_decr = tbm_perc_decr;

    // load bitmaps
    bitmaps := new(Bitmaps);
    bitmaps.body_h = sdl2.LoadBMP("body_h.bmp")
    bitmaps.body_v = sdl2.LoadBMP("body_v.bmp")
    bitmaps.head_d = sdl2.LoadBMP("head_d.bmp")
    bitmaps.head_l = sdl2.LoadBMP("head_l.bmp")
    bitmaps.head_r = sdl2.LoadBMP("head_r.bmp")
    bitmaps.head_u = sdl2.LoadBMP("head_u.bmp")
    bitmaps.tail_d = sdl2.LoadBMP("tail_d.bmp")
    bitmaps.tail_l = sdl2.LoadBMP("tail_l.bmp")
    bitmaps.tail_r = sdl2.LoadBMP("tail_r.bmp")
    bitmaps.tail_u = sdl2.LoadBMP("tail_u.bmp")
    bitmaps.turn_d_l = sdl2.LoadBMP("turn_d_l.bmp")
    bitmaps.turn_d_r = sdl2.LoadBMP("turn_d_r.bmp")
    bitmaps.turn_u_l = sdl2.LoadBMP("turn_u_l.bmp")
    bitmaps.turn_u_r = sdl2.LoadBMP("turn_u_r.bmp")
    bitmaps.chili = sdl2.LoadBMP("chili.bmp")

    game.bitmaps = bitmaps;

        // make the snake!
    snake := new(Snake);
    snake.segments = make([dynamic]Segment);
    snake.direction = .LEFT

    // grow the snake! in the center! to the left!
    center_y :=  (WINDOW_HEIGHT / 2);
    center_x := (WINDOW_WIDTH / 2);

    // add the head!
    head := Drawable{sdl2.Rect{center_x, center_y , block_size, block_size}, bitmaps.head_l, .SNAKE};
    game.coords_to_draw[{head.rect.x, head.rect.y}] = head;
    head_segment := Segment{head, .LEFT}
    append(&snake.segments, head_segment);

    for i : i32 = 1; i < snake_initial_len - 1; i += 1 {
        x := center_x + (block_size * i);
        body := Drawable{sdl2.Rect{x, center_y , block_size, block_size}, bitmaps.body_h, .SNAKE};
        body_segment := Segment{body, .LEFT};
        append(&snake.segments, body_segment);
        game.coords_to_draw[{x, center_y}] = body;
    }    
    // add the tail!
    tail := Drawable{sdl2.Rect{center_x + ((snake_initial_len - 1) * block_size), center_y , block_size, block_size}, bitmaps.tail_l, .SNAKE};
    tail_segment := Segment{tail, .LEFT};
    game.coords_to_draw[{tail.rect.x, tail.rect.y}] = tail;
    append(&snake.segments, tail_segment);

    snake.last_direction = .LEFT;
    snake.next_direction = .LEFT;

    game.snake = snake;
    return game
}

run :: proc(window : ^sdl2.Window, game : ^Game) {   
    last_move_time :u32;
    move_lock :bool = false;

    for game.running {
        draw(window, game);

        if !game.fruit_placed {
            // assuming that a free place for a fruit is found, this is an endless loop. Maybe think about how to do this differently?
            for {
                x := rand.int32_range(1, game.fWidthInBlocks) * game.block_size;
                y := rand.int32_range(1, game.fHeightInBlocks) * game.block_size;

                elem, key_found := game.coords_to_draw[{x, y}];
                if !key_found {
                    fruit := Drawable{sdl2.Rect{x, y, game.block_size, game.block_size}, game.bitmaps.chili, .FRUIT};
                    game.coords_to_draw[{x, y}] = fruit;
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
                            game.snake.last_direction = game.snake.direction;
                            game.snake.next_direction = .UP;
                        }
                    case .s:
                        if game.snake.direction != .UP {
                            game.snake.last_direction = game.snake.direction;       
                            game.snake.next_direction = .DOWN;
                        }
                    case .a:
                        if game.snake.direction != .RIGHT {
                            game.snake.last_direction = game.snake.direction;          
                            game.snake.next_direction = .LEFT;
                        }
                    case .d:
                        if game.snake.direction != .LEFT {
                            game.snake.last_direction = game.snake.direction;
                            game.snake.next_direction = .RIGHT;
                        }
                }
            }            
        }
        
        current_time := sdl2.GetTicks();
        if (current_time - last_move_time) >= u32(game.time_btw_moves) && !move_lock {
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

    for to_draw, drawable in game.coords_to_draw {         
        rect := drawable.rect;
        sdl2.BlitScaled(drawable.bitmap, nil, surface, &rect);
    }
    sdl2.UpdateWindowSurface(window);
}
 


move_snake :: proc (game : ^Game) {    
    remove_tail := true;
    snake := game.snake;
    snake.direction = snake.next_direction;
    new_head_segment := snake.segments[0];
    switch snake.direction {
        case .UP: {
            new_head_segment.drawable.rect.y -= game.block_size;
            new_head_segment.drawable.bitmap = game.bitmaps.head_u;
        }
        case .DOWN: {
            new_head_segment.drawable.rect.y += game.block_size;
            new_head_segment.drawable.bitmap = game.bitmaps.head_d;
        }
        case .LEFT: {
            new_head_segment.drawable.rect.x -= game.block_size;
            new_head_segment.drawable.bitmap = game.bitmaps.head_l;
        }
        case .RIGHT: {
            new_head_segment.drawable.rect.x += game.block_size;
            new_head_segment.drawable.bitmap = game.bitmaps.head_r;
        }
    }

    // check if new head is out of bounds
    rect := new_head_segment.drawable.rect;
    if rect.x < game.block_size || rect.x >= game.fWidth || rect.y < game.block_size || rect.y >= game.fHeight {
        game.running = false;
        return;
    }

    // check if new head would collide with smth
    elem, key_found := game.coords_to_draw[{rect.x, rect.y}];
    if key_found {
        switch elem.type {
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

    new_head_segment.direction = snake.direction;
    inject_at(&snake.segments, 0, new_head_segment);    
    game.coords_to_draw[{rect.x, rect.y}] = new_head_segment.drawable;

    before_head := &snake.segments[1].drawable;

    switch snake.last_direction {
        case .UP: {
            #partial switch snake.direction {
                case .LEFT:
                    before_head.bitmap = game.bitmaps.turn_d_l;
                case .RIGHT:
                    before_head.bitmap = game.bitmaps.turn_d_r;
                case :
                    before_head.bitmap = game.bitmaps.body_v;
            }
        }
        case .DOWN: {
            #partial switch snake.direction {
                case .LEFT:
                    before_head.bitmap = game.bitmaps.turn_u_l;
                case .RIGHT:
                    before_head.bitmap = game.bitmaps.turn_u_r;
                case :
                    before_head.bitmap = game.bitmaps.body_v;
            }            
        }
        case .LEFT: {
            #partial switch snake.direction {
                case .UP:
                    before_head.bitmap = game.bitmaps.turn_u_r;
                case .DOWN:
                    before_head.bitmap = game.bitmaps.turn_d_r;
                case :
                    before_head.bitmap = game.bitmaps.body_h;
            }
        }
        case .RIGHT: {
            #partial switch snake.direction {
                case .UP:
                    before_head.bitmap = game.bitmaps.turn_u_l;
                case .DOWN:
                    before_head.bitmap = game.bitmaps.turn_d_l;
                case :
                    before_head.bitmap = game.bitmaps.body_h;
            }
        }
    }

    game.coords_to_draw[{before_head.rect.x, before_head.rect.y}] = before_head^;

    snake.last_direction = snake.direction;
        
    if remove_tail {
        tail := pop(&snake.segments);
        delete_key(&game.coords_to_draw, [2]i32{tail.drawable.rect.x, tail.drawable.rect.y});
        new_tail := &snake.segments[len(snake.segments) - 1];

        direction_before_tail := snake.segments[len(snake.segments) - 2].direction;

        switch direction_before_tail {
            case .LEFT:
                new_tail.drawable.bitmap = game.bitmaps.tail_l;
            case .RIGHT: 
                new_tail.drawable.bitmap = game.bitmaps.tail_r;
            case .UP:
                new_tail.drawable.bitmap = game.bitmaps.tail_u;
            case .DOWN:
                new_tail.drawable.bitmap = game.bitmaps.tail_d;
        }
        game.coords_to_draw[{new_tail.drawable.rect.x, new_tail.drawable.rect.y}] = new_tail.drawable
    }
}

destroy_game :: proc(game: ^Game) {    
    delete(game.snake.segments);
    free(game.snake);
    delete(game.coords_to_draw);

    free(game);

}