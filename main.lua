window_width = 480
window_height = 640
math.randomseed(os.time())

function love.load()
  love.window.setMode(window_width, window_height, {resizable=false})
  love.window.setTitle("Flappy Bird")

  background_day_sprite = love.graphics.newImage("sprites/background-day.png")
  
  -- Carregando as informações iniciais do jogador
  player = {}
  player.posx = 160
  player.posy = 250
  player.rotation = 0
  player.mid_sprite = love.graphics.newImage("sprites/yellowbird-midflap.png")
  player.up_sprite = love.graphics.newImage("sprites/yellowbird-upflap.png")
  player.down_sprite = love.graphics.newImage("sprites/yellowbird-downflap.png")
  player.width = player.mid_sprite:getWidth()/2
  player.height = player.mid_sprite:getHeight()/2
  player.points = 0
  player.sprite_on = player.down_sprite -- Define a sprite inicial do jogador
  player.animation_label = "initial" -- Define a animação do jogador
  player.posy_animation_start = player.posx -- Define a posição inicial do jogador durante uma animação
  player.alive = true -- Define se o jogador está vivo
  player.on_ground = false -- Define se o jogador já está no chão
  player.die_reason = nil -- Controla se o som de queda deve tocar ou não (ele só toca quando o jogador bate no cano)
  
  -- Carregando as sprites dos números
  numbers = {
    [0] = love.graphics.newImage("sprites/0.png"),
    [1] = love.graphics.newImage("sprites/1.png"),
    [2] = love.graphics.newImage("sprites/2.png"),
    [3] = love.graphics.newImage("sprites/3.png"),
    [4] = love.graphics.newImage("sprites/4.png"),
    [5] = love.graphics.newImage("sprites/5.png"),
    [6] = love.graphics.newImage("sprites/6.png"),
    [7] = love.graphics.newImage("sprites/7.png"),
    [8] = love.graphics.newImage("sprites/8.png"),
    [9] = love.graphics.newImage("sprites/9.png"),
  }
  numbers.width = 24
  numbers.space_between = 4 -- Espaço que será colocado entre os números
  numbers.posy = 20 -- Altura que os numeros serão desenhados

  -- Carregando as informações iniciais das bases
  base_sprite = love.graphics.newImage("sprites/base.png")
  base_height = base_sprite:getHeight()
  base_width = base_sprite:getWidth()
  base1 = {}
  base2 = {}
  
  base1.x = 0
  base1.y = window_height - base_height
  base1.sprite = base_sprite
    
  base2.x = window_width
  base2.y = window_height - base_height
  base2.sprite = base_sprite
  
  pipes = {}
  pipes.sprite = love.graphics.newImage("sprites/pipe-green.png")
  pipes.width = pipes.sprite:getWidth()
  pipes.height = pipes.sprite:getHeight()
  pipes.space_between = player.height * 7 -- Definição do espaço entre os canos superior e inferior
  pipes.upper_limit = 100 -- Limite superior (x) de geração do cano
  pipes.low_limit = base1.y - pipes.upper_limit - pipes.space_between -- Limite inferior é calculado utilizando a coordenada do chão, o limite superior e o espaço entre os canos
  pipes.coords = {}
  -- Gerando 4 pipes para o inicio do jogo
  for i = 1, 4 do
    generatePipe()
  end
  
  -- Carregando informações iniciais sobre as animações do jogo
  animations = {}
  animations["initial"] = {}
  animations["initial"].speed = 0.2 -- Define a velocidade da animação inicial (passáro indo para cima e bara baixo)
  animations["initial"].limit_up = -8 -- Define a altura máxima que o passáro pode chegar durante a animação
  animations["initial"].limit_down = 8 -- Define a altura miníma que o passáro pode chegar durante a animação
  animations["initial"].state = nil -- Define o atual estado da animação, (nil, up ou down)
  
  animations["fly"] = {}
  animations["fly"].strength = 7 -- Define a quantidade de pixels que o passáro sobe por execução
  animations["fly"].strength_default = 7
  animations["fly"].strength_down = 0.7 -- Define a perda de força durante cada execução
  animations["fly"].limit_up = -30 -- Define a altura máxima que o passáro chega em um pulo
  animations["fly"].state = nil -- Estado inicial da animação
  animations["fly"].count = 0 -- Contador para a animação
  
  animations["fall"] = {}
  animations["fall"].strength = 0.1 -- Define a força de queda
  animations["fall"].strength_default = 0.1 
  animations["fall"].strength_up = 0.05 -- Define o ganho da força de queda a cada execução
  animations["fall"].count = 0 -- Contador para a animação
  animations["fall"].str_start_factor = 10 -- Define quando o passáro começa a rotacionar em direção ao chao. Quanto maior, mais demora
  
  animations["wing"] = {}
  animations["wing"].speed = 1 -- Precisa ser menor que count_limit, ou será executado todo frame
  animations["wing"].state = 0 -- Define a primeira asa a ser desenhada (min:0, max: 3)
  animations["wing"].count = 0 -- Contador para a animação
  animations["wing"].count_limit = 10
  
  animations["base"] = {}
  animations["base"].speed = 1.5
  
  animations["pipes"] = {}
  animations["pipes"].speed = animations["base"].speed
  
  -- Carregando os audios do jogo
  audios = {}
  audios.wing = love.audio.newSource("audio/wing.wav", "static")
  audios.hit = love.audio.newSource("audio/hit.wav", "static")
  audios.point = love.audio.newSource("audio/point.wav", "static")
  audios.die = love.audio.newSource("audio/die.wav", "static")
  die_song_played = false
end


function love.draw()
  -- Chamando as funções de desenho
  love.graphics.draw(background_day_sprite, 0, 0)
  drawPipes()
  drawPlayer()
  drawBase()
  drawnPoints()
end

function love.update()
  --[[ Único controle do jogo é a tecla espaço
    Se o jogador estiver vivo, ela faz o jogador pular
    Se estiver morto e no chão, reinicia o jogo
  ]]
  if player.alive then
    if love.keyboard.isDown("space") then
      playerStopFall()
      player.animation_label = "fly"
      audios.wing:play()
    end
    -- Se o jogador estiver vivo, é verificado se existe colisão com o chão ou com os canos
    playerBaseCollision()
    playerPipeCollision()
  elseif player.on_ground then
    if love.keyboard.isDown("space") then
      restartGame()
    end
  end
end

function restartGame()
  -- Redefinindo valores iniciais do jogo
  playerStopFall()
  player.die_reason = nil
  player.animation_label = "initial"
  player.posx = 160
  player.posy = 250
  player.rotation = 0
  player.points = 0
  player.posy_animation_start = player.posx
  player.alive = true
  player.on_ground = false
  pipes.coords = {}
  for i = 1, 4 do
    generatePipe()
  end
end

function playerBaseCollision()
  --[[
    Essa função verifica se a largura do jogador mais a sua posição no eixo y
    (o que resulta na posição exata da parte de baixo durante a queda) é maior que a posição do chão no eixo y. Se for, há colisão
  ]]
  if (player.posy + player.width > window_height - base_height  and player.rotation > 1.3059) or (player.posy + player.height > window_height - base_height) then
    audios.hit:play()
    player.alive = false
    player.die_reason = "base-collision"
  end
end

function playerFlyAnimation()
  --A animação de voo inicia já na primeira iteração, aumentando a rotação em 30 graus
  -- Quando for o inicio da animação, é armazenada a posição inicial afim de delimitar a altura que o jogador chega com um pulo, e o estado da animação é definida como "up", para não cair nesse if novamente
  if animations[player.animation_label].state == nil then
    player.posy_animation_start = player.posy
    animations[player.animation_label].state = "up"
  end
  
  --[[ 
    Quando o jogador atingir o limite de altura com um pulo, o status da animação é definido novamente como nulo e a força de voo é restaurada. 
    A animação do jogador é definida como "fall", para iniciar a queda na próxima iteração
  ]]
  if player.posy < player.posy_animation_start + animations[player.animation_label].limit_up then
    animations[player.animation_label].state = nil
    player.animation_label = "fall"
    animations["fly"].strength = animations["fly"].strength_default
  else 
    player.posy = player.posy - animations[player.animation_label].strength -- Aumentando a posição do jogador
    animations[player.animation_label].strength = animations[player.animation_label].strength - animations[player.animation_label].strength_down -- Diminuindo a força de voo a cada iteração com a função
    rotation_factor = animations[player.animation_label].limit_up / 2 -- Calculando o fator de rotação, que é utilizado para determina o momento em que as rotações são aplicadas
    if player.posy_animation_start - player.posy < rotation_factor then
      player.rotation = -0.5236 -- 30 graus
    elseif player.posy_animation_start - player.posy > rotation_factor then
      player.rotation = -0.7854 -- 45 graus
    end
  end
end

function playerWingAnimation()
  --[[ A velocidade da animação é definida com base em uma soma simples, que é armazenada em um contador.
      A cada frame, o contador recebe o valor da velocidade definida na animação
      Quando o contador for maior que o seu limite (count_limit), uma animação  executada
      ]]
  
  if animations["wing"].count < animations["wing"].count_limit then
    animations["wing"].count = animations["wing"].count + animations["wing"].speed
    return
  end
  
  --[[ A lógica da ordem das animações é definida da seguinte maneira: asa no meio, para cima, no meio e para baixo.
      A váriavel state controla qual sprite será utilizada no próximo frame, e ela pode variar de 0 até 3.
      Ao final de cada alteração da asa, o status recebe mais um caso ele seja menor que 3, e se for maior, state recebe o valor 0
  ]]
  if animations["wing"].state == 0 then
    player.sprite_on = player.mid_sprite
  elseif animations["wing"].state == 1 then
    player.sprite_on = player.up_sprite
  elseif animations["wing"].state == 2 then
    player.sprite_on = player.mid_sprite
  elseif animations["wing"].state == 3 then
    player.sprite_on = player.down_sprite
  end
  
  if animations["wing"].state < 3 then
    animations["wing"].state = animations["wing"].state + 1
  else
    animations["wing"].state = 0
  end
  
  animations["wing"].count = 0
  
end

function playerStopFall()
  -- Função que reseta a queda assim que o jogador voa
  animations["fall"].count = 0
  animations["fall"].strength = animations["fall"].strength_default
end

function playerFallAnimation()
  --[[
    A animação da queda do jogador inicia quando o contador da animação tiver o valor equivalente a força de queda multiplicada pelo fator de iniciação da queda
    E assim que começa, cada vez que o contador aumentar em determinados valores, ele continuará caindo
    Em cada interação, o valor da rotação do jogador (em radianos) é alterada
  ]]
  if animations[player.animation_label].count <= animations[player.animation_label].strength * animations[player.animation_label].str_start_factor then
    player.rotation = -0.524
  elseif animations[player.animation_label].count <= animations[player.animation_label].strength * (animations[player.animation_label].str_start_factor + 2) then
    player.rotation = -0.262
  elseif animations[player.animation_label].count <= animations[player.animation_label].strength * (animations[player.animation_label].str_start_factor + 4) then
    player.rotation = 0
  elseif animations[player.animation_label].count <= animations[player.animation_label].strength * (animations[player.animation_label].str_start_factor + 6) then
    player.rotation = 0.262
  elseif animations[player.animation_label].count <= animations[player.animation_label].strength * (animations[player.animation_label].str_start_factor + 8) then
    player.rotation = 0.524
  elseif animations[player.animation_label].count <= animations[player.animation_label].strength * (animations[player.animation_label].str_start_factor + 10) then
    player.rotation = 0.785
  elseif animations[player.animation_label].count <= animations[player.animation_label].strength * (animations[player.animation_label].str_start_factor + 12) then
    player.rotation = 1.047
  elseif animations[player.animation_label].count <= animations[player.animation_label].strength * (animations[player.animation_label].str_start_factor + 13) then
    player.rotation = 1.309
  elseif animations[player.animation_label].count <= animations[player.animation_label].strength * (animations[player.animation_label].str_start_factor + 14) then
    player.rotation = 1.571
  end
  
  if not player.alive and player.rotation >= 0.262 and player.animation_label and not die_song_played and player.die_reason == "pipe-collision" then
    audios.die:play()
    die_song_played = true
  end
  
  if player.posy + player.width <= window_height - base_height then
    -- Reduzindo a altura do jogador
    player.posy = player.posy + animations[player.animation_label].strength
      -- Aumentando a força da queda a cada iteraço
    animations[player.animation_label].count = animations[player.animation_label].count + animations[player.animation_label].strength
    animations[player.animation_label].strength = animations[player.animation_label].strength + animations[player.animation_label].strength_up
  else
    player.on_ground = true
  end
    
end

function initialPlayerAnimation()
  --[[
    Essa função controla a animação inicial do jogador, onde voa suavemente para cima e para baixo
  ]]
  
  -- Se o estado da animação for nulo, então ele começa indo para cima
  if animations[player.animation_label].state == nil then
    player.posy_animation_start = player.posy
    animations[player.animation_label].state = "up"
  end
  
  -- Se o estado da animação for "up",  verificado se ele já chegou no limite de altura
  if animations[player.animation_label].state == "up" then
    if player.posy < player.posy_animation_start + animations[player.animation_label].limit_up then
      -- Se chegou no limite de altura, na próxima ele vai para baixo
      animations[player.animation_label].state = "down" 
    else
      -- Se não chegou, continua indo para cima
      player.posy = player.posy - animations[player.animation_label].speed
    end
  else 
    -- Mesma lógica do limite superior, porém aplicada para o limite inferior
    if player.posy > player.posy_animation_start + animations[player.animation_label].limit_down then
      animations[player.animation_label].state = "up"
    else
      player.posy = player.posy + animations[player.animation_label].speed
    end
  end
end

function drawPlayer()
  -- Faz a animação da asa enquanto o jogador estiver vivo
  if player.alive then
    playerWingAnimation()
  end
  
  -- Verifica a animação atual do jogador e aplica as modificações nele
  if player.animation_label == "initial" then
    initialPlayerAnimation()
  elseif player.animation_label == "fly" then
    playerFlyAnimation()
  elseif player.animation_label == "fall" then
    playerFallAnimation()
  end
  
  -- Desenhando o jogador
  love.graphics.draw(player.sprite_on, player.posx, player.posy, player.rotation, 1, 1, player.width, player.height)
end

function drawBase()
  -- A animação do chão é feita com dois "chãos", um ao lado do outro, que se movimentam junto.

  if player.alive then
    -- Aplicando a animação no chão reduzindo as coordenadas no eixo x
    base1.x = base1.x - animations["base"].speed
    base2.x = base2.x - animations["base"].speed
  end
  
  --[[
  Se a posição x do chão 2 for menor que 0, indica que ele está passando da tela.
  Dito isso, eu falo que a posição x do chão 1 é igual a do chão 2. E a posição do chão 1 é igual a ele mesno + largura do chão.
  Com isso, é aplicada a animação.
  ]]
  if base2.x < 0 then
    base1.x = base2.x
    base2.x = base1.x + base_width
  end
  -- Desenhando os chãos em suas respectivas posiçõies
  love.graphics.draw(base1.sprite, base1.x, base1.y)
  love.graphics.draw(base2.sprite, base2.x, base2.y)
end

function drawPipes()
  -- Se aanimação do jogador não for a inicial, os canos se aproximam do jogador
  if player.animation_label ~= "initial" then
    for i = 1, #pipes.coords do
      -- Aplicando rotação de 90 graus para o cano de cima (já que na sprite a ponta do cano está para cima
      love.graphics.draw(pipes.sprite, pipes.coords[i].x, pipes.coords[i].y1 - pipes.height, 3.14159, 1, 1, pipes.width, pipes.height)
      love.graphics.draw(pipes.sprite, pipes.coords[i].x, pipes.coords[i].y2)
      if player.alive then 
        -- Se o jogador estiver vivo, atualizo as coordenadas do cano
        pipes.coords[i].x = pipes.coords[i].x - animations["pipes"].speed
      end
    end
  end
end

function drawnPoints()
  --[[
    Essa função obtém o número de ponto do jogador, e com base no resto da divisão
    por 10 vai separando os digitos e colocando-os em uma table, de maneira que seja
    possível desenha-los depois
    Tudo isso apenas para obter cada digito separadamente, porque o número pode ter mais de um
  ]]
  local points = player.points
  local digits = {}
  if points > 0 then
    while points > 0 do
      local digit = points % 10
      
      table.insert(digits, 1, digit)
      
      points = math.floor(points / 10)
    end
  
  else
    table.insert(digits, 1, 0)
  end
  
  --[[ 
    Calculo da posição inicial do primeiro digito com base na 
    quantidade de digitos existentes e seus espaçamentos
  ]]
  local initial_position = (window_width - ((#digits - 1) * numbers.space_between + #digits * numbers.width))/ 2
  for _, value in ipairs(digits) do
      love.graphics.draw(numbers[value], initial_position, numbers.posy)
    if value == 1 then -- O digito 1  a única sprite menor que as outras, gambiarra para corrigir o espaçamento
      initial_position = initial_position + numbers.width + numbers.space_between - 8
    else
      initial_position = initial_position + numbers.width + numbers.space_between
    end
  end
end

function playerPipeCollision()
  --[[
    Funço responsável por:
      - Apagar canos que já passaram da tela
      - Gerar novos canos
      - Aumentar pontuação do jogador quando ele passa completamente de um cano
      - Verificar colisão do jogador com os canos
  ]]
  
  -- Para cada cano existente, se ele já não foi passado pelo jogador, verifico a colisão
  for i = 1, #pipes.coords do
    if not pipes.coords[i].defeated then
      --[[
        Verifico:
          - Colisão do lado esquerdo do cano em relação ao jogador
          - Se o jogador ainda está antes do lado direito do cano (se ele já passou ou não)
          - Se o jogador não está no espaço entre os canos
        Se tudo for válidado, indica colisão
      ]]
      if pipes.coords[i].x <= player.posx + player.height and pipes.coords[i].x + pipes.width * 1.5 >= player.posx + player.width and not (pipes.coords[i].y1 + 14 < player.posy and pipes.coords[i].y2 > player.posy + player.height) then
        audios.hit:play()
        player.alive = false
        player.die_reason = "pipe-collision"
      elseif pipes.coords[i].x + pipes.width < player.posx then
        --[[
          Se o jogador não bateu no cano que está seno avaliado, e já passou dele,
          ele recebe um ponto e o audio de pontuação é tocado.
          O cano também  atualizado para "passado", para ser 
          excluido posteriormente e no cair mais nas verificações de colisão
        ]]
        player.points = player.points + 1
        pipes.coords[i].defeated = true
        audios.point:play()
      end
    end
  end
  
  --[[
    Se o primeiro cano da lista já tiver sido passado, e a coordenada x dele
    estiver fora da tela, ele é removido e é gerado outro cano no final da table
  ]]
  if pipes.coords[1].defeated and pipes.coords[1].x + pipes.width < 0 then
    table.remove(pipes.coords, 1)
    generatePipe()
  end
end

function generatePipe()
  --[[
    Função responsável por gerar novos canos aleatóriamente
  ]]
  
  -- Calculo da coordenada y do cano superior aleatório
  new_upper_pipe = math.random(pipes.upper_limit, pipes.low_limit)
  pipe = {}
  pipe.y1 = new_upper_pipe
  -- Definição da posição do cano inferior com base no cano superior e o espaço entre os canos
  pipe.y2 = new_upper_pipe + pipes.space_between 
  pipe.defeated = false
  
  -- Se for o primeiro cano a ser gerado, ele é criado fora da tela, com meia tela de espaço para fora
  if #pipes.coords == 0 then
    pipe.x = 1.5 * window_width
  else
    -- Se não for o primeiro cano, a cordenada x do novo cano é calculada com base na coordenada x 
    -- do ultimo cano, mais metade do espaço da largura da janela
    pipe.x = pipes.coords[#pipes.coords].x + window_width / 2
  end
  
  -- Insiro o cano na table
  table.insert(pipes.coords, pipe)
end