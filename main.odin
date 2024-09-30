package main

import "core:fmt"
import "core:os"
import "core:math/rand"
import "core:math"
import "core:strings"

import sdl "vendor:sdl2"
import img "vendor:sdl2/image"
import ttf "vendor:sdl2/ttf"
import mix "vendor:sdl2/mixer"

// constants for the game
SDL_FLAGS :: sdl.INIT_EVERYTHING
IMG_FLAGS :: img.INIT_PNG | img.INIT_JPG
WINDOW_FLAGS :: sdl.WINDOW_SHOWN
RENDER_FLAGS :: sdl.RENDERER_ACCELERATED
MIX_FLAGS :: mix.INIT_OGG
CHUNK_SIZE :: 1024

WINDOW_TITLE :: "Pong"
SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 600

FONT_SIZE :: 25
FONT_COLOR :: sdl.Color{255,255,255,255}
TEXT_VEL :: 1
SPRITE_VEL :: 1
BALL_SPEED :: 7
PLAYER_SPEED :: 2
ENEMY_SPEED :: 1
OFFSET :: 10

PLAYER_START_X :: 0
PLAYER_START_Y :: SCREEN_HEIGHT/2
ENEMY_START_X :: SCREEN_WIDTH - 10
ENEMY_START_Y :: SCREEN_HEIGHT/2
PADDLE_HEIGHT :: 50
PADDLE_WIDTH :: 10
PADDLE_SPEED :: 6
BALL_WIDTH :: 10
BALL_HEIGHT :: 10
BALL_START_X :: SCREEN_WIDTH/2
BALL_START_Y :: SCREEN_HEIGHT/2
SCORE : string


GameState :: enum{Start, Play, Pause}


Game :: struct {
    // basic game struct

    window: ^sdl.Window,
    renderer : ^sdl.Renderer,
    event: sdl.Event,
    text_rect: sdl.Rect,
    pause_rect: sdl.Rect,
    start_rect: sdl.Rect,
    text_image: ^sdl.Texture,
    pause_image: ^sdl.Texture,
    start_image: ^sdl.Texture,
    text_xvel : i32,
    text_yvel : i32,
    sprite_image: ^sdl.Texture,
    sprite_rect: sdl.Rect,
    keystate: [^]u8,
    music: ^mix.Music,
    state : GameState,
    player, enemy, ball : sdl.Rect,
    ball_xvel : i32,
    ball_yvel : i32,
    player_score : i32,
    enemy_score: i32,
    score_text: cstring,
    pause_text : cstring,
    start_text: cstring,
    ping_sound : ^mix.Chunk,
    score_sound : ^mix.Chunk,
    no_sound : bool
}

game_cleanup :: proc(g: ^Game) {
    // clean up after closing
    if g != nil {
        mix.HaltChannel(-1)
        mix.HaltMusic()

        if g.no_sound==false {

        if g.music != nil {mix.FreeMusic(g.music)}
        if g.ping_sound != nil {mix.FreeChunk(g.ping_sound)}
        if g.score_sound != nil {mix.FreeChunk(g.score_sound)}
        
        }

        if g.sprite_image != nil {sdl.DestroyTexture(g.sprite_image)}
        if g.text_image != nil {sdl.DestroyTexture(g.text_image)}
        if g.pause_image != nil{sdl.DestroyTexture(g.pause_image)}
        if g.start_image!= nil{sdl.DestroyTexture(g.start_image)}
        if g.renderer != nil {sdl.DestroyRenderer(g.renderer)}
        if g.window != nil {sdl.DestroyWindow(g.window)}

        mix.CloseAudio()
        mix.Quit()
        ttf.Quit()
        img.Quit()
        sdl.Quit()
        fmt.println("clearup")
    }

}

initialize :: proc(g: ^Game) -> bool {
    // initializing game
    // exits when sth is wrong
    // starting basic library
    no_sound := false
    if sdl.Init(SDL_FLAGS) !=0{
        fmt.eprintfln("error with sdl %s", sdl.GetError())
        return false
    }

    img_init := img.Init(IMG_FLAGS)

    if (img_init & IMG_FLAGS) != IMG_FLAGS {
        fmt.eprintfln("error with SDL Image %s", sdl.GetError())
        return false
    }

    if ttf.Init() != 0 {
		fmt.eprintfln("Error initializing SDL2_TTF: %s", ttf.GetError())
		return false
	}

    mix_init := mix.Init(MIX_FLAGS)
    if (mix_init & i32(MIX_FLAGS)) != i32(MIX_FLAGS) {
        fmt.eprintfln("error with SDL Mixer %s", mix.GetError())
        return false
    }

    if mix.OpenAudio(mix.DEFAULT_FREQUENCY,mix.DEFAULT_FORMAT,mix.DEFAULT_CHANNELS,CHUNK_SIZE) !=0 {
        g.no_sound = true
        fmt.eprintfln("error with Open Audio %s", mix.GetError())
        // return false
    }

    // create window
    g.window = sdl.CreateWindow(
         WINDOW_TITLE,
         sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED,
         SCREEN_WIDTH,
         SCREEN_HEIGHT,
         WINDOW_FLAGS
        )
    
    if g.window == nil 
        {
            fmt.eprintfln("error creating window: %s", sdl.GetError())
            return false
        }
    g.renderer = sdl.CreateRenderer(g.window, -1, RENDER_FLAGS)

    // create renderer
    if g.renderer == nil 
        {
            fmt.eprintfln("error creating renderer: %s", sdl.GetError())
            return false
        }

    // icon in window
    icon_surf := img.Load("SDL.png")

    if icon_surf == nil 
    {
        fmt.eprintfln("error loading icon: %s", img.GetError())
        return false
    }

    sdl.SetWindowIcon(g.window,icon_surf)
    sdl.FreeSurface(icon_surf)

    // positions of textures and paddles

    g.text_xvel = TEXT_VEL
    g.text_yvel = TEXT_VEL

    g.keystate = sdl.GetKeyboardState(nil)

    g.state = GameState.Start

    g.player.w= PADDLE_WIDTH
    g.player.h= PADDLE_HEIGHT

    g.player.x= 0
    g.player.y= SCREEN_HEIGHT/2
    
    g.enemy.w= PADDLE_WIDTH
    g.enemy.h= PADDLE_HEIGHT
    g.enemy.x= SCREEN_WIDTH - OFFSET
    g.enemy.y= SCREEN_HEIGHT/2
    

    g.ball.x=SCREEN_WIDTH/2
    g.ball.y=SCREEN_HEIGHT/2
    g.ball.w=BALL_WIDTH
    g.ball.h=BALL_HEIGHT

    g.ball_xvel = BALL_SPEED
    g.ball_yvel = BALL_SPEED
    
    g.player_score=0
    g.enemy_score=0

    // initializing texts
    g.score_text = fmt.ctprintf("Player: %i Enemy: %i", g.player_score,g.enemy_score) 
    g.pause_text = fmt.ctprintf("Pause")
    g.start_text = fmt.ctprintf("Press any key to start ")

    // game state in beginning
    g.state = GameState.Start

    return true
}



load_media :: proc(g: ^Game) -> bool {
    
    // loads font and music
    // exits if files are not found

    font := ttf.OpenFont("font/pico-8.ttf", FONT_SIZE)
    if font == nil {
        fmt.eprintfln("error opening font: %s", ttf.GetError())
        return false
    }

    font_surface := ttf.RenderText_Blended(font,g.score_text,FONT_COLOR)
    

    if font_surface == nil {
        fmt.eprintfln("error creating text surface: %s", ttf.GetError())
        return false
    }

    g.text_rect.w = font_surface.w
    g.text_rect.h = font_surface.h

    g.text_image = sdl.CreateTextureFromSurface(g.renderer,font_surface)
    sdl.FreeSurface(font_surface)
    if g.text_image== nil {
        fmt.eprintfln("error creating image texture",sdl.GetError())
        return false
    }

    font_surface_pause := ttf.RenderText_Blended(font,g.pause_text,FONT_COLOR)
    g.pause_image = sdl.CreateTextureFromSurface(g.renderer,font_surface_pause)
    sdl.FreeSurface(font_surface_pause)
    if g.pause_image== nil {
        fmt.eprintfln("error creating pause texture",sdl.GetError())
        return false
    }

    font_surface_start := ttf.RenderText_Blended(font,g.start_text,FONT_COLOR)
    g.start_image = sdl.CreateTextureFromSurface(g.renderer,font_surface_start)
    sdl.FreeSurface(font_surface_start)
    if g.start_image == nil {
        fmt.eprintfln("error creating start texture",sdl.GetError())
        return false
    }
    ttf.CloseFont(font)

    g.sprite_image=img.LoadTexture(g.renderer,"SDL.png")
    if g.sprite_image == nil {
        fmt.eprintfln("error loading: %s", img.GetError())
        return false
    }

    if sdl.QueryTexture(g.sprite_image,nil,nil,&g.sprite_rect.w,
    &g.sprite_rect.h) != 0 {
        fmt.eprintfln("Error querying texture: %s", img.GetError())
        return false
    }

    // load sound if it exists
    if g.no_sound == false {

    g.music = mix.LoadMUS("music/freesoftwaresong-8bit.ogg")
    g.ping_sound = mix.LoadWAV("sounds/ping.wav")
    g.score_sound = mix.LoadWAV("sounds/score.wav")

    if g.music == nil {
        fmt.eprintfln("error loading Music : %s", mix.GetError())
        return false
    }

    if mix.PlayMusic(g.music,-1) != 0 {
        fmt.eprintfln("error playing Music : %s", mix.GetError())
        return false
    }

    if g.ping_sound == nil  {
        fmt.eprintfln("error loading Sound File : %s", mix.GetError())
        return false
    }

    if g.score_sound == nil {
        fmt.eprintfln("error loading score sound : %s", mix.GetError())
        return false
    }

    if mix.PlayChannel(-1,g.ping_sound,0) != 0  {
        fmt.eprintfln("error playing sound : %s", mix.GetError())
        return false
    }

    if mix.PlayChannel(0,g.score_sound,0) != 0 {
        fmt.eprintfln("error playing score sound : %s", mix.GetError())
        return false 
    }

    }
    

    return true
}



draw_paddle :: proc(g: ^Game) {
   // paddle drawing
    sdl.RenderFillRect(g.renderer,&g.ball)
    sdl.RenderFillRect(g.renderer,&g.player)
    sdl.RenderFillRect(g.renderer,&g.enemy)
}

text_update :: proc(g: ^Game) {
    g.text_rect.x += TEXT_VEL 
    if g.text_rect.x < 0 {
        g.text_xvel = TEXT_VEL       
    }
    if g.text_rect.x + g.text_rect.w > SCREEN_WIDTH {
        g.text_xvel = -TEXT_VEL
    }

    g.text_rect.y += g.text_yvel 
    if g.text_rect.y < 0 {
        g.text_yvel = TEXT_VEL       
    }

    if g.text_rect.y + g.text_rect.h > SCREEN_HEIGHT {
        g.text_yvel = -TEXT_VEL      
    }

}

score_update :: proc(g: ^Game) {
    // draw score update on surface
    g.score_text = fmt.ctprintf("Player: %i Enemy: %i", g.player_score,g.enemy_score)
    font := ttf.OpenFont("font/pico-8.ttf", FONT_SIZE)
    font_surface := ttf.RenderText_Blended(font,g.score_text,FONT_COLOR)
    ttf.CloseFont(font)
    g.text_rect.w = font_surface.w
    g.text_rect.h = font_surface.h

    g.text_image = sdl.CreateTextureFromSurface(g.renderer,font_surface)
    sdl.FreeSurface(font_surface)



}

draw_pause :: proc(g: ^Game) {
    // draw pause text on surface
    font := ttf.OpenFont("font/pico-8.ttf", FONT_SIZE)
    font_surface_pause := ttf.RenderText_Blended(font,g.pause_text,FONT_COLOR)
    ttf.CloseFont(font)
    g.pause_rect.w = font_surface_pause.w
    g.pause_rect.h = font_surface_pause.h

    g.pause_image = sdl.CreateTextureFromSurface(g.renderer,font_surface_pause)
    sdl.FreeSurface(font_surface_pause)
}

draw_start :: proc(g: ^Game) {
    // draw start text on surface
    font := ttf.OpenFont("font/pico-8.ttf", FONT_SIZE)
    font_surface_start := ttf.RenderText_Blended(font,g.start_text,FONT_COLOR)
    ttf.CloseFont(font)
    g.start_rect.w = font_surface_start.w
    g.start_rect.h = font_surface_start.h

    g.start_image = sdl.CreateTextureFromSurface(g.renderer,font_surface_start)
    sdl.FreeSurface(font_surface_start)
}


ball_update :: proc(g: ^Game, score_sound: ^mix.Chunk) {
    // updates ball pisition every frame
    g.ball.x += g.ball_xvel

    // increase score, reset and play sound for player and enemy
    if g.ball.x < 0 {
        g.ball_xvel = BALL_SPEED
        g.enemy_score += 1
        g.ball.x=SCREEN_WIDTH/2
        g.ball.y=SCREEN_HEIGHT/2
        mix.PlayChannel(0,score_sound,0)
    }

    if g.ball.x + g.ball.w > SCREEN_WIDTH {
        g.ball_xvel = -BALL_SPEED
        g.player_score +=1
        g.ball.x=SCREEN_WIDTH/2
        g.ball.y=SCREEN_HEIGHT/2
        mix.PlayChannel(0,score_sound,0)
    }

    g.ball.y += g.ball_yvel
    
    if g.ball.y < 0 {
        g.ball_yvel = BALL_SPEED + 1
    }

    if g.ball.y + g.ball.h > SCREEN_HEIGHT {
        g.ball_yvel= -BALL_SPEED + 1     
    }
    

}

toggle_music ::proc() {
    // toggle music on off for pause
    if mix.PausedMusic() == 1 {
        mix.ResumeMusic()
    } else {
        mix.PauseMusic()
    }

}

paddle_collision :: proc(ball:^sdl.Rect,paddle:^sdl.Rect, ping_sound:^mix.Chunk) -> bool {
    // collision of paddle and ball
    // returns true if hit else false

    ballLeft := ball.x;
	ballRight := ball.x + BALL_WIDTH;
    
	ballTop := ball.y;
	ballBottom := ball.y + BALL_HEIGHT;

    paddleLeft := paddle.x;
	paddleRight := paddle.x + PADDLE_WIDTH;

	paddleTop :=  paddle.y;
	paddleBottom :=  paddle.y + PADDLE_HEIGHT;

	if (ballLeft >= paddleRight)
	{       
		return false;
	}

	if (ballRight <= paddleLeft)
	{
		return false;
	}

	if (ballTop >= paddleBottom)  
	{
		return false;
	}

	if (ballBottom <= paddleTop)
	{
		return false;
	}
    // play ping for collision
    mix.PlayChannel(-1,ping_sound,0)
	return true;

}

reset :: proc(g: ^Game) {
    // Reset Game and score
    
    g.player.y = PLAYER_START_Y
    g.enemy.y = ENEMY_START_Y
    g.enemy_score = 0
    g.player_score = 0
    g.ball.x = BALL_START_X
    g.ball.y = BALL_START_Y

    // x direction randomly -1 or 1
    xdirectons: [2]i32 = { -1 , 1 }
    rand_choice_x := rand.choice(xdirectons[:])
    //g.ball_xvel = rand.choice(data[:])*BALL_SPEED
    if rand_choice_x==1 {g.ball_xvel = BALL_SPEED}
    else if rand_choice_x==-1 {g.ball_xvel = -BALL_SPEED}

    // y direction chosen randomly
    // 3,2,1 not there to increase speed
    // 0 is horizontal

    ydirectons : [11]i32 = { -8,-7,-6,-5,-4, 0, 4, 5,6,7,8}
    ydirection := rand.choice(ydirectons[:])
    ydirection = rand.choice(xdirectons[:])* ydirection
    fmt.printf("%i ",ydirection)
    //g.ball_xvel = rand.choice(data[:])*BALL_SPEED
    g.ball_yvel = ydirection   
}

game_run :: proc(g: ^Game) {

    player_up := false
    player_down := false
    enemy_up := false
    enemy_down := false

    collision := false
    collision_enemy := false
    reset_game := false
    

    for {
        // events
        // P for Pause
        
        if g.state==GameState.Play{
            for sdl.PollEvent(&g.event) {
                #partial switch g.event.type {
                case .QUIT:
                    return
                case .KEYDOWN:
                    #partial switch g.event.key.keysym.scancode 
                    {
                        case .ESCAPE:
                            return
                        case .UP:
                            enemy_up = true
                        case .R:
                            reset_game = true
                        case .DOWN:
                            enemy_down = true
                        case .S:
                            player_down = true 
                        case .W:
                            player_up = true
                        case .P: 
                            g.state = GameState.Pause
                            
                    }
                    // to enable multiple presses at once, enables first and second player input
                case .KEYUP:
                    #partial switch g.event.key.keysym.scancode 
                    {
                        
                        case .UP:
                            enemy_up = false      
                        case .DOWN:
                            enemy_down = false         
                        case .S:
                            player_down = false                  
                        case .W:
                            player_up = false
                            
                    }
                }
            }
            if reset_game == true {       
                reset(g)
                reset_game = false
            }
    
            if player_up == true && player_down == false  {
                g.player.y -= PADDLE_SPEED
            }
            else if player_up == false && player_down == true &&
                g.enemy.y + g.enemy.h/2 < SCREEN_HEIGHT {
                g.player.y += PADDLE_SPEED
            }
            if g.enemy.y + g.enemy.h/2 > 0 || g.enemy.y + g.enemy.h/2 < SCREEN_HEIGHT {
                g.player.y = g.player.y
            }
    
            if enemy_up == true && enemy_down ==false{
                g.enemy.y -= PADDLE_SPEED
            }
            else if enemy_up == false && enemy_down == true {
                g.enemy.y += PADDLE_SPEED
            }
            if g.player.y + g.player.h/2 > 0 ||  g.player.y + g.player.h/2 < SCREEN_HEIGHT{
                g.enemy.y = g.enemy.y
            }
    
        }
        else if g.state == GameState.Pause {
            for sdl.PollEvent(&g.event) {
                #partial switch g.event.type {
                    
                    case .KEYDOWN:
                        #partial switch g.event.key.keysym.scancode 
                    {
                        case .P:
                                g.state=GameState.Play    
                        }                 
                    case .KEYUP:   
                    #partial switch g.event.key.keysym.scancode 
                    {                     
                        case .P:
                                g.state = GameState.Pause 
                        }
                    
                }
               
            }
        }  
        else if g.state == GameState.Start {
             // press any key to start
            for sdl.PollEvent(&g.event) {
                #partial switch g.event.type {
                    
                    case .KEYDOWN:
                    {
                        // switch state to play and play music
                        g.state=GameState.Play   
                        mix.PlayMusic(g.music,-1) 
                    }                                    
                }
               
            }
        }
        


        // update
        // text_update(g)
        if g.state == GameState.Play{

            ball_update(g,g.score_sound)
        
            // Update score
            score_update(g)      
            // Check collision
            
            if paddle_collision(&g.ball,&g.player,g.ping_sound){
                fmt.printf("player collision")
                g.ball_xvel = BALL_SPEED
            }
            else if paddle_collision(&g.ball,&g.enemy,g.ping_sound){
                fmt.printf("collision")
                g.ball_xvel -= BALL_SPEED   
            }
        }
       
    
        // drawing
        // clear background to black
        sdl.SetRenderDrawColor(g.renderer, 
            0,0,0, 
            255)
        sdl.RenderClear(g.renderer)

        
        // text color
        
        sdl.SetRenderDrawColor(g.renderer, 
            255,255,255, 
            255)    
            g.text_rect.x = 200
            g.text_rect.y = 20
    
    
            g.pause_rect.x = SCREEN_WIDTH/2 - 10
            g.pause_rect.y = SCREEN_HEIGHT/2 + 10
        // during start don't draw score
        if g.state != GameState.Pause{
            sdl.RenderCopy(g.renderer,g.text_image, nil, &g.text_rect)
        }
       
        // start update
        g.start_rect.x = SCREEN_WIDTH/2 - 40
        g.start_rect.y = SCREEN_HEIGHT/2  - 20

        if g.state == GameState.Start{    
            if g.no_sound==false {
                mix.PauseMusic()
                mix.Pause(-1)
                mix.Pause(0)
                }   
       
                draw_start(g)
                sdl.RenderCopy(g.renderer,g.start_image, nil, &g.start_rect)
               }

        // render ball, paddle color
        sdl.SetRenderDrawColor(g.renderer, 
            255,0,0, 
            255)
        
        // sprite_update(g) when state=Play
        if g.state == GameState.Play{draw_paddle(g)}

        // if pause display pause
        if g.state == GameState.Pause{
            if g.no_sound==false {
                mix.PauseMusic()
                mix.Pause(-1)
                mix.Pause(0)
            } 
            draw_pause(g)
            sdl.RenderCopy(g.renderer,g.pause_image, nil, &g.pause_rect)
        }
        
        // Color or line
        sdl.SetRenderDrawColor(g.renderer, 
            214,120,0, 
            125)

        // Draw line in middle
        for i := 0; i < SCREEN_HEIGHT; i += 1 {
            if (i%5!=0)
                {
                    sdl.RenderDrawPoint(g.renderer,SCREEN_WIDTH/2,i32(i))
                }
        }

        sdl.RenderPresent(g.renderer)
        sdl.Delay(16)
    }
}

main :: proc() {
    exit_status := 0
    game: Game 

    defer{
        game_cleanup(&game)
        os.exit(exit_status)
    }

    if !initialize(&game) {
        exit_status=1
        return
    }

    if !load_media(&game) {
        exit_status=1
        return
    }
    
    game_run(&game)
   
}