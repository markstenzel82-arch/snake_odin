package snake;

import "core:fmt";
import "core:os";
import "vendor:sdl2";
import "core:math/rand";

Direction :: enum i32 {
    UP = -1,
    DOWN = -2,
    LEFT = 4,
    RIGHT = 8    
}

DrawableType :: enum i32 {
    HEAD = 16,
    V_STRAIGHT = 32,
    H_STRAIGHT = 64,
    TURN = 128,
    TAIL = 256,
    FRUIT = 512
}

Game :: struct {
    snake : ^Snake,
    bitmaps : map[i32]^sdl2.Surface,
    coords_to_draw : map[[2]i32]Drawable,        
    block_size : i32,
    fWidth : i32,
    fHeight : i32,
    fWidthInBlocks : i32,
    fHeightInBlocks : i32,
    score : u32,  
    frame_samples : u32, 
    avg_frame_ms : f32,
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

make_bitmaps :: proc() -> map[i32]^sdl2.Surface {
    bitmaps := make(map[i32]^sdl2.Surface);    

    // body
    bitmaps[i32(DrawableType.V_STRAIGHT)] = sdl2.LoadBMP("bitmaps/body_v.bmp");
    bitmaps[i32(DrawableType.H_STRAIGHT)] = sdl2.LoadBMP("bitmaps/body_h.bmp");

    // head
    bitmaps[i32(DrawableType.HEAD) + i32(Direction.UP)] = sdl2.LoadBMP("bitmaps/head_u.bmp");
    bitmaps[i32(DrawableType.HEAD) + i32(Direction.DOWN)] = sdl2.LoadBMP("bitmaps/head_d.bmp");
    bitmaps[i32(DrawableType.HEAD) + i32(Direction.LEFT)] = sdl2.LoadBMP("bitmaps/head_l.bmp");
    bitmaps[i32(DrawableType.HEAD) + i32(Direction.RIGHT)] = sdl2.LoadBMP("bitmaps/head_r.bmp");

    //  tail
    bitmaps[i32(DrawableType.TAIL) + i32(Direction.UP)] = sdl2.LoadBMP("bitmaps/tail_u.bmp");
    bitmaps[i32(DrawableType.TAIL) + i32(Direction.DOWN)] = sdl2.LoadBMP("bitmaps/tail_d.bmp");
    bitmaps[i32(DrawableType.TAIL) + i32(Direction.LEFT)] = sdl2.LoadBMP("bitmaps/tail_l.bmp");
    bitmaps[i32(DrawableType.TAIL) + i32(Direction.RIGHT)] = sdl2.LoadBMP("bitmaps/tail_r.bmp");

    // turn
    turn_d_l := sdl2.LoadBMP("bitmaps/turn_d_l.bmp")
    turn_d_r := sdl2.LoadBMP("bitmaps/turn_d_r.bmp")
    turn_u_l := sdl2.LoadBMP("bitmaps/turn_u_l.bmp")
    turn_u_r := sdl2.LoadBMP("bitmaps/turn_u_r.bmp")    

    // turn_d_l
    bitmaps[i32(DrawableType.TURN) + (i32(Direction.UP) - i32(Direction.LEFT))] = turn_d_l;
    bitmaps[i32(DrawableType.TURN) + (i32(Direction.RIGHT) - i32(Direction.DOWN))] = turn_d_l;

    // turn d_r
    bitmaps[i32(DrawableType.TURN) + (i32(Direction.UP) - i32(Direction.RIGHT))] = turn_d_r;
    bitmaps[i32(DrawableType.TURN) + (i32(Direction.LEFT) - i32(Direction.DOWN))] = turn_d_r;

    // turn_u_l
    bitmaps[i32(DrawableType.TURN) + (i32(Direction.DOWN) - i32(Direction.LEFT))] = turn_u_l;
    bitmaps[i32(DrawableType.TURN) + (i32(Direction.RIGHT) - i32(Direction.UP))] = turn_u_l;

    // turn_u_r
    bitmaps[i32(DrawableType.TURN) + (i32(Direction.DOWN) - i32(Direction.RIGHT))] = turn_u_r;
    bitmaps[i32(DrawableType.TURN) + (i32(Direction.LEFT) - i32(Direction.UP))] = turn_u_r;

    // fruit
    bitmaps[i32(DrawableType.FRUIT)] = sdl2.LoadBMP("bitmaps/chili.bmp");
    
    return bitmaps;
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
    
    bitmaps := make_bitmaps();
    game.bitmaps = bitmaps;

        // make the snake!
    snake := new(Snake);
    snake.segments = make([dynamic]Segment);
    snake.direction = .LEFT

    // grow the snake! in the center! to the left!
    center_y :=  (WINDOW_HEIGHT / 2);
    center_x := (WINDOW_WIDTH / 2);

    // add the head!
    head := Drawable{sdl2.Rect{center_x, center_y , block_size, block_size}, bitmaps[i32(DrawableType.HEAD) + i32(Direction.LEFT)], DrawableType.HEAD};
    game.coords_to_draw[{head.rect.x, head.rect.y}] = head;
    head_segment := Segment{head, .LEFT}
    append(&snake.segments, head_segment);

    for i : i32 = 1; i < snake_initial_len - 1; i += 1 {
        x := center_x + (block_size * i);
        body := Drawable{sdl2.Rect{x, center_y , block_size, block_size}, bitmaps[i32(DrawableType.H_STRAIGHT)], DrawableType.H_STRAIGHT};
        body_segment := Segment{body, .LEFT};
        append(&snake.segments, body_segment);
        game.coords_to_draw[{x, center_y}] = body;
    }    
    // add the tail!
    tail := Drawable{sdl2.Rect{center_x + ((snake_initial_len - 1) * block_size), center_y , block_size, block_size}, bitmaps[i32(DrawableType.TAIL) + i32(Direction.LEFT)] , DrawableType.TAIL};
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

    for game.running {
        frame_start := sdl2.GetPerformanceCounter();
        draw(window, game);

        if !game.fruit_placed {
            // assuming that a free place for a fruit is found, this is an endless loop. Maybe think about how to do this differently?
            for {
                x := rand.int32_range(1, game.fWidthInBlocks) * game.block_size;
                y := rand.int32_range(1, game.fHeightInBlocks) * game.block_size;

                elem, key_found := game.coords_to_draw[{x, y}];
                if !key_found {
                    fruit := Drawable{sdl2.Rect{x, y, game.block_size, game.block_size}, game.bitmaps[i32(DrawableType.FRUIT)], DrawableType.FRUIT};
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
        if (current_time - last_move_time) >= u32(game.time_btw_moves) {
            move_snake(game);
            last_move_time = current_time;            
        }
        frame_ms := f64(sdl2.GetPerformanceCounter() - frame_start) / f64(sdl2.GetPerformanceFrequency()) * 1000.0;
        game.frame_samples += 1;
        game.avg_frame_ms += (f32(frame_ms) - game.avg_frame_ms) / f32(game.frame_samples);
    }
    fmt.println("GAME OVER, MAN! GAME OVER! OVER! OVER! OVER! OVEr! OVer! Over! over! ove! ov! o!");
    fmt.printf("avg frame: %.2f ms (%.0f FPS) over %d frames\n",
           game.avg_frame_ms, 1000.0 / game.avg_frame_ms, game.frame_samples);

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
        case .UP:
            new_head_segment.drawable.rect.y -= game.block_size;
        case .DOWN:
            new_head_segment.drawable.rect.y += game.block_size;
        case .LEFT:
            new_head_segment.drawable.rect.x -= game.block_size;
        case .RIGHT: 
            new_head_segment.drawable.rect.x += game.block_size;        
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
        #partial switch elem.type {            
            case .FRUIT: {
                // YUM! NOMNOMNOM!
                remove_tail = false;
                game.fruit_placed = false;
                game.time_btw_moves *= game.tbm_perc_decr;
            }
            case : {
                // DEADLY COLLISION! ABORT!
                game.running = false;
                return;
            }
        }
    }

    new_head_segment.drawable.bitmap = game.bitmaps[i32(DrawableType.HEAD) + i32(snake.direction)];

    new_head_segment.direction = snake.direction;
    inject_at(&snake.segments, 0, new_head_segment);    
    game.coords_to_draw[{rect.x, rect.y}] = new_head_segment.drawable;

    before_head := &snake.segments[1].drawable;  

    if i32(snake.last_direction) * i32(snake.direction) < 0 { // direction change 90 degrees, turn needed
        before_head.type = DrawableType.TURN;
        before_head.bitmap = game.bitmaps[i32(DrawableType.TURN) + (i32(snake.last_direction) - i32(snake.direction))];
    } else {
        if snake.direction == Direction.UP || snake.direction == Direction.DOWN {
            before_head.type = DrawableType.V_STRAIGHT;
            before_head.bitmap = game.bitmaps[i32(DrawableType.V_STRAIGHT)];
        } else {
            before_head.type = DrawableType.H_STRAIGHT;
            before_head.bitmap = game.bitmaps[i32(DrawableType.H_STRAIGHT)];
        }
    }    

    game.coords_to_draw[{before_head.rect.x, before_head.rect.y}] = before_head^;

    subtracted : i32 = i32(snake.last_direction - snake.direction);
    fmt.printf("last_direction: %s, direction: %s subtracted: %d\n", snake.last_direction, snake.direction, subtracted);

    snake.last_direction = snake.direction;
        
    if remove_tail {
        tail := pop(&snake.segments);
        delete_key(&game.coords_to_draw, [2]i32{tail.drawable.rect.x, tail.drawable.rect.y});
        new_tail := &snake.segments[len(snake.segments) - 1];

        direction_before_tail := snake.segments[len(snake.segments) - 2].direction;

        switch direction_before_tail {
            case .LEFT:
                new_tail.drawable.bitmap = game.bitmaps[i32(DrawableType.TAIL) + i32(Direction.LEFT)];
            case .RIGHT: 
                new_tail.drawable.bitmap = game.bitmaps[i32(DrawableType.TAIL) + i32(Direction.RIGHT)];
            case .UP:
                new_tail.drawable.bitmap = game.bitmaps[i32(DrawableType.TAIL) + i32(Direction.UP)];
            case .DOWN:
                new_tail.drawable.bitmap = game.bitmaps[i32(DrawableType.TAIL) + i32(Direction.DOWN)];
        }
        game.coords_to_draw[{new_tail.drawable.rect.x, new_tail.drawable.rect.y}] = new_tail.drawable
    }
}

destroy_game :: proc(game: ^Game) {    
    delete(game.snake.segments);
    delete(game.bitmaps);
    free(game.snake);
    delete(game.coords_to_draw);
    free(game);

}