import
  random,
  sdl2_nim/sdl,
  std/math,
  std/tables,
  std/enumerate,
  std/strutils,
  std/strformat

const
  Title = "SDL2 App"
  ScreenW = 640 # Window width
  ScreenH = 480 # Window height
  WindowFlags = 0
  RendererFlags = sdl.RendererAccelerated or sdl.RendererPresentVsync


type
  App = ref AppObj
  AppObj = object
    window*: sdl.Window # Window pointer
    renderer*: sdl.Renderer # Rendering state pointer


proc init(app: App): bool =
  # Init SDL
  if sdl.init(sdl.InitVideo) != 0:
    sdl.logCritical(sdl.LogCategoryError,
                    "Can't initialize SDL: %s",
                    sdl.getError())
    return false

  # Create window
  app.window = sdl.createWindow(
    Title,
    sdl.WindowPosUndefined,
    sdl.WindowPosUndefined,
    ScreenW,
    ScreenH,
    WindowFlags)
  if app.window == nil:
    sdl.logCritical(sdl.LogCategoryError,
                    "Can't create window: %s",
                    sdl.getError())
    return false

  # Create renderer
  app.renderer = sdl.createRenderer(app.window, -1, RendererFlags)
  if app.renderer == nil:
    sdl.logCritical(sdl.LogCategoryError,
                    "Can't create renderer: %s",
                    sdl.getError())
    return false

  # Set draw color
  if app.renderer.setRenderDrawColor(0x00, 0x00, 0x00, 0x00) != 0:
    sdl.logWarn(sdl.LogCategoryVideo,
                "Can't set draw color: %s",
                sdl.getError())
    return false

  sdl.logInfo(sdl.LogCategoryApplication, "SDL initialized successfully")
  randomize()
  return true

# Shutdown sequence
proc exit(app: App) =
  app.renderer.destroyRenderer()
  app.window.destroyWindow()
  sdl.logInfo(sdl.LogCategoryApplication, "SDL shutdown completed")
  sdl.quit()


  # Event handling
# Return true on app shutdown request, otherwise return false
proc events(pressed: var seq[sdl.Keycode]): bool =
  result = false
  var e: sdl.Event
  if pressed.len > 0:
    pressed = @[]

  while sdl.pollEvent(addr(e)) != 0:

    # Quit requested
    if e.kind == sdl.Quit:
      return true

    # Key pressed
    elif e.kind == sdl.KeyDown:
      # Add pressed key to sequence
      pressed.add(e.key.keysym.sym)

      # Exit on Escape key press
      if e.key.keysym.sym == sdl.K_Escape:
        return true


proc `>>`(app: App) =
    app.renderer.renderPresent()
    discard app.renderer.renderClear()

    if app.renderer.setRenderDrawColor(0x00, 0x00, 0x00, 0x00) != 0:
        sdl.logWarn(sdl.LogCategoryVideo,
                "Can't set draw color: %s",
                sdl.getError())


###############################################################################GAME LOOP#########################################################


const
    PADDLE_HEIGHT = 90
    PADDLE_WIDTH = 24

    PADDLE_PLAYER_X = 0
    PADDLE_OPPONENT_X = ScreenW - PADDLE_WIDTH

    MIDDLE_LINE_X = ScreenW div 2
    MIDDLE_LINE_Y = 0
    MIDDLE_LINE_WIDTH = 20
    MIDDLE_LINE_HIGHT = ScreenH

    PADDLE_SPEED_PLAYER = 8
    PADDLE_SPEED_OPPONENT = 16

    RADIUS = 8
    RADIUS_MULT_TWO = RADIUS shl 1

    POSSIBLE_INIT_SPEEDS = [-6, 6]

    STOP_TIME = 25

    DELAY_TIME = 800

    DID_BOUNCE_TIME = 50



var
    app = App(window: nil, renderer: nil)
    done = false # Main loop exit condition
    pressed: seq[sdl.Keycode] = @[] # Pressed keys
  
    paddlePlayerY = ScreenH div 2
    paddleOpponentY = ScreenH div 2

    paddlePlayer = sdl.Rect(x: PADDLE_PLAYER_X, 
        y: paddlePlayerY, w: PADDLE_WIDTH, h: PADDLE_HEIGHT)
    paddleOpponent = sdl.Rect(x: PADDLE_OPPONENT_X, 
        y: paddleOpponentY, w: PADDLE_WIDTH, h: PADDLE_HEIGHT)
    middleLine = sdl.Rect(x: MIDDLE_LINE_X, y: MIDDLE_LINE_Y, 
        w: MIDDLE_LINE_WIDTH, h: MIDDLE_LINE_HIGHT)
    

    xi = ScreenW div 2
    yi = ScreenH div 2

    xSpeed = POSSIBLE_INIT_SPEEDS.sample()
    ySpeed = POSSIBLE_INIT_SPEEDS.sample()

    opponentPaddleDir = -1

    speedCoeff = 1

    stopBounce = false

    tick: uint32 = STOP_TIME

    ballCollisionPoint = 0

    didBouncePlayer = false

    tickDidBounce = DID_BOUNCE_TIME


proc drawMiddleLine(app: App) =
    discard app.renderer.setRenderDrawColor(0x11, 0xCF, 0x0D, 0x0EE)
    
    discard app.renderer.renderFillRect(addr(middleLine))

    discard app.renderer.setRenderDrawColor(0x00, 0x00, 0x00, 0x00)


proc drawOpponentPaddle(app: App) = 
    discard app.renderer.setRenderDrawColor(0x11, 0xCF, 0x0D, 0x0EE)
    
    paddleOpponent.y = paddleOpponentY

    discard app.renderer.renderFillRect(addr(paddleOpponent))

    discard app.renderer.setRenderDrawColor(0x00, 0x00, 0x00, 0x00)



proc drawPlayerPaddle(app: App) = 
    discard app.renderer.setRenderDrawColor(0x11, 0xCF, 0x0D, 0x0EE)
    
    paddlePlayer.y = paddlePlayerY

    discard app.renderer.renderFillRect(addr(paddlePlayer))

    discard app.renderer.setRenderDrawColor(0x00, 0x00, 0x00, 0x00)


type
  possiblePlayerActions = enum
    goUp, goDown, doNothing

  gameState = enum
    playerLost, opponentLost, playing


var 
  stateOfGameBuffer: seq[gameState] = @[gameState.playing, gameState.playing]
  bufferIndex = 0

proc calculateStateOfGame() =
  if xi >= ScreenW:
    stateOfGameBuffer[bufferIndex] = gameState.opponentLost

  if xi <= 0:
    stateOfGameBuffer[bufferIndex] = gameState.playerLost

  if xi >= 0 and xi < ScreenW:
    stateOfGameBuffer[bufferIndex] = gameState.playing

  if bufferIndex == 0:
    bufferIndex = 1
  else:
    bufferIndex = 0





var actionDo = possiblePlayerActions.doNothing



proc controlPlayerPaddle() = 
  #let kbd = sdl.getKeyboardState(nil)

  if actionDo == possiblePlayerActions.doNothing:
    paddlePlayerY += 0

  if actionDo == possiblePlayerActions.goUp and paddlePlayerY > 0:
    paddlePlayerY -= PADDLE_SPEED_PLAYER
  
  if actionDo == possiblePlayerActions.goDown and paddlePlayerY < ScreenH - PADDLE_HEIGHT:
    paddlePlayerY += PADDLE_SPEED_PLAYER


  if stopBounce and paddlePlayerY >= (ScreenH div 2):
    paddlePlayerY -= PADDLE_SPEED_PLAYER div 2
  elif stopBounce and paddlePlayerY < (ScreenH div 2):
    paddlePlayerY += PADDLE_SPEED_PLAYER div 2


proc drawBall(app: App) = 
    discard app.renderer.setRenderDrawColor(0xFF, 0xFF, 0xFF, 0xFF)

    var x: int = RADIUS - 1
    var y: int = 0

    var tx: int = 1
    var ty: int = 1

    var err = tx - RADIUS_MULT_TWO

    while x >= y:
      discard app.renderer.renderDrawPoint(xi + x, yi + y)
      discard app.renderer.renderDrawPoint(xi + y, yi + x)
      discard app.renderer.renderDrawPoint(xi - y, yi + x)
      discard app.renderer.renderDrawPoint(xi - x, yi + y)
      discard app.renderer.renderDrawPoint(xi - x, yi - y)
      discard app.renderer.renderDrawPoint(xi - y, yi - x)
      discard app.renderer.renderDrawPoint(xi + y, yi - x)
      discard app.renderer.renderDrawPoint(xi + x, yi - y)

      if err <= 0:
        inc(y)
        err += ty
        ty += 2

      if err > 0:
        dec(x)
        tx += 2
        err += tx - RADIUS_MULT_TWO

    discard app.renderer.setRenderDrawColor(0x00, 0x00, 0x00, 0x00)


proc stopBounceTimer(interval: uint32, param: pointer): uint32 {.cdecl.} =
  tick -= 1
  if tick == 0:
    xSpeed *= -1
    ySpeed *= -1
    xi += xSpeed * 5
    yi += ySpeed * 5
    stopBounce = false

  return tick




proc stopTheBounce() =
  stopBounce = true
  var timer = sdl.addTimer(STOP_TIME, stopBounceTimer, nil)

  if timer == 0:
    discard sdl.removeTimer(timer)    


proc didBounceTimer(interval: uint32, param: pointer): uint32 {.cdecl.} =
  tickDidBounce -= 1
  if tickDidBounce == 0:
   didBouncePlayer = false

  return tick




proc doTheDidBounce() =
  didBouncePlayer = true
  var timer = sdl.addTimer(STOP_TIME, didBounceTimer, nil)

  if timer == 0:
    discard sdl.removeTimer(timer)    

proc `<->`(xSpeedX, ySpeedX: int) = 
    if not stopBounce:    
      xi += xSpeedX
      yi += ySpeedX
    else:
      xi = PADDLE_PLAYER_X + PADDLE_WIDTH
      yi = paddlePlayerY + ballCollisionPoint

    if xi <= PADDLE_PLAYER_X + (PADDLE_WIDTH div 2) and yi >= paddlePlayerY and yi < paddlePlayerY + PADDLE_HEIGHT:
      ballCollisionPoint = yi - paddlePlayerY
      if not stopBounce:
        tick = STOP_TIME
        stopTheBounce()

      if not didBouncePlayer:
        tickDidBounce = DID_BOUNCE_TIME
        doTheDidBounce()
      


    if xi >= PADDLE_OPPONENT_X - (PADDLE_WIDTH div 2) and  yi >= paddleOpponentY and yi < paddleOpponentY + PADDLE_HEIGHT:
      xSpeed *= -1
      ySpeed *= -1
      didBouncePlayer = false


    if yi <= 0 or yi >= ScreenH:
      ySpeed *= -1



proc `?>`(xii, yii: int) = 

    if xii <= -PADDLE_WIDTH or xii >= ScreenW + PADDLE_WIDTH:
        delay(DELAY_TIME)
        didBouncePlayer = false
        xi = ScreenW div 2
        yi = ScreenH div 2
        xSpeed = POSSIBLE_INIT_SPEEDS.sample()
        ySpeed = POSSIBLE_INIT_SPEEDS.sample()
        paddlePlayerY = ScreenH div 2
        paddleOpponentY = ScreenH div 2
  

###################################AI####################333###############################3


const 
    MIN_DIST = 60
    MIN_DIST_NEAR = 60

var
    goUpper = false
    goDowner = false
    speedUp = false
    resetPos = false
    isNear = false


proc `~~~>`(pnt1, pnt2: (int, int)): float =
    var powOne = (pnt2[0] - pnt1[0]) ^ 2
    var powTwo = (pnt2[1] - pnt1[1]) ^ 2

    var addition = float(powTwo + powOne)

    result = sqrt(addition)




proc `|`(aAndB, A: float): float = 
    result = aAndB / A


proc `|`(aAndB, A: int): float = 
    result = aAndB / A

proc calcSpeedUp() =
    var distBallTop = (xi, yi)~~~>(PADDLE_OPPONENT_X - PADDLE_WIDTH, paddleOpponentY)
    var distBallMiddle = (xi, yi)~~~>(PADDLE_OPPONENT_X - PADDLE_WIDTH, paddleOpponentY + (PADDLE_HEIGHT div 2))
    var distBallBottom = (xi, yi)~~~>(PADDLE_OPPONENT_X - PADDLE_WIDTH, paddleOpponentY + PADDLE_HEIGHT)


    var probDistTop = distBallTop|MIN_DIST
    var probDistNearTop = distBallTop|MIN_DIST_NEAR
    var probDistMiddle = distBallMiddle|MIN_DIST
    var probDistNearMiddle = distBallMiddle|MIN_DIST_NEAR
    var probDistBottom = distBallBottom|MIN_DIST
    var probDistNearBottom  = distBallBottom|MIN_DIST_NEAR


    var isNearTop = probDistNearTop < 1.0
    var speedUpTop = probDistTop >= 0.5 and probDistTop < 1.0
    var isNearMiddle = probDistNearMiddle < 1.0
    var speedUpMiddle = probDistMiddle >= 0.5 and probDistMiddle < 1.0
    var isNearBottom  = probDistNearBottom  < 1.0
    var speedUpBottom  = probDistBottom  >= 0.5 and probDistBottom  < 1.0

    isNear = isNearBottom or isNearTop or isNearMiddle
    speedUp = speedUpBottom or speedUpMiddle or speedUpTop

    if speedup:
      speedCoeff = 10
    else:
      speedCoeff = 1




proc calcGoUp() =
    var probYHeight = float(yi)|float(ScreenH)
    var probXWidth = float(xi)|float(ScreenW)


    goUpper = probYHeight <= 0.5 and probXWidth >= 0.75


proc calcGoDown() =
    var probYHeight = float(yi)|float(ScreenH)
    var probXWidth = float(xi)|float(ScreenW)

    goDowner = probYHeight >= 0.5 and probXWidth >= 0.75


proc calcReset() = 
    var probXWidth = float(xi)|float(ScreenW)

    resetPos = probXWidth <= 0.75

    

proc `+->`(opX: int) =
    calcSpeedUp()
    calcReset()
    calcGoUp()
    calcGoDown()

    var dontResetPos = not resetPos
    var isDown = paddleOpponentY >= 0
    var isUp = paddleOpponentY <= ScreenH - PADDLE_HEIGHT
    var inMiddle =  paddleOpponentY - (ScreenH div 2)
    var sign = (if inMiddle == 0: 0 else: abs(inMiddle) div inMiddle)
    var localResPos = resetPos and inMiddle != 0


    if localResPos:
      paddleOpponentY += -sign * PADDLE_SPEED_OPPONENT
    if goUpper and isDown and dontResetPos and not localResPos and not isNear:
      paddleOpponentY -= PADDLE_SPEED_OPPONENT * speedCoeff
    if goDOwner and isUp and dontResetPos and not localResPos and not isNear:
      paddleOpponentY += PADDLE_SPEED_OPPONENT * speedCoeff
    
        


##############################Q-Learning############################################################################3


type 
  ActionMap* = object
    goUp: float
    goDown: float
    doNothing: float

  StateMap* = object
    state: ActionMap

var actionStateTable = {
      "ballNear": {
          "above": StateMap(state: ActionMap(goUp: rand(2.0), goDown: rand(2.0), doNothing:  rand(2.0))),
          "below": StateMap(state: ActionMap(goUp: rand(2.0), goDown: rand(2.0), doNothing:  rand(2.0))), 
          "level": StateMap(state: ActionMap(goUp: rand(2.0), goDown: rand(2.0), doNothing:  rand(2.0))), 

      
      }.toTable(),
      "ballClose": {
          "above": StateMap(state: ActionMap(goUp: rand(2.0), goDown: rand(2.0), doNothing:  rand(2.0))),
          "below": StateMap(state: ActionMap(goUp: rand(2.0), goDown: rand(2.0), doNothing:  rand(2.0))), 
          "level": StateMap(state: ActionMap(goUp: rand(2.0), goDown: rand(2.0), doNothing:  rand(2.0))), 

      }.toTable(),
      "ballWReach": {
          "above": StateMap(state: ActionMap(goUp: rand(2.0), goDown: rand(2.0), doNothing:  rand(2.0))),
          "below": StateMap(state: ActionMap(goUp: rand(2.0), goDown: rand(2.0), doNothing:  rand(2.0))), 
          "level": StateMap(state: ActionMap(goUp: rand(2.0), goDown: rand(2.0), doNothing:  rand(2.0))), 

      }.toTable(),
       "ballOReach": {
          "above": StateMap(state: ActionMap(goUp: rand(2.0), goDown: rand(2.0), doNothing:  rand(2.0))),
          "below": StateMap(state: ActionMap(goUp: rand(2.0), goDown: rand(2.0), doNothing:  rand(2.0))), 
          "level": StateMap(state: ActionMap(goUp: rand(2.0), goDown: rand(2.0), doNothing:  rand(2.0))), 

      }.toTable()

    }.toTable()

 




const
  DENUM_NEAR = ScreenW div 8
  DENUM_CLOSE = ScreenW div 6
  DENUM_WREACH = ScreenW div 4
  DENUM_OREACH = ScreenW div 2


  ABOVE = ScreenH div 2
  BELOW = ScreenH - (ScreenH div 2)
  LEVEL = ScreenH div 2



var 
  currStateOuter = "ballNear"
  currStateInner = "above"


proc getState() =
  let 
    distBallTop = (xi, yi)~~~>(PADDLE_PLAYER_X - PADDLE_WIDTH, paddlePlayerY)
    distBallMiddle = (xi, yi)~~~>(PADDLE_PLAYER_X - PADDLE_WIDTH, paddlePlayerY + (PADDLE_HEIGHT div 2))
    distBallBottom = (xi, yi)~~~>(PADDLE_PLAYER_X - PADDLE_WIDTH, paddlePlayerY + PADDLE_HEIGHT)


    ballTopNear = distBallTop|DENUM_NEAR <= 1.0
    ballMiddleNear = distBallMiddle|DENUM_NEAR <= 1.0
    ballBottomNear = distBallBottom|DENUM_NEAR <= 1.0

    ballTopClose = distBallTop|DENUM_CLOSE <= 1.0
    ballMiddleClose = distBallMiddle|DENUM_CLOSE <= 1.0
    ballBottomClose = distBallBottom|DENUM_CLOSE <= 1.0

    ballTopWReach = distBallTop|DENUM_WREACH <= 1.0
    ballMiddleWReach = distBallMiddle|DENUM_WREACH <= 1.0
    ballBottomWReach = distBallBottom|DENUM_WREACH <= 1.0

    ballTopOReach = distBallTop|DENUM_OREACH <= 1.0
    ballMiddleOReach = distBallMiddle|DENUM_OREACH <= 1.0
    ballBottomOReach = distBallBottom|DENUM_OREACH <= 1.0




  if ballTopNear or ballMiddleNear or ballBottomNear:
    currStateOuter = "ballNear"
  elif ballTopClose or ballMiddleClose or ballBottomClose:
    currStateOuter = "ballClose"
  elif ballTopWReach or ballMiddleWReach or ballBottomWReach:
    currStateOuter = "ballWReach"
  elif ballTopOReach or ballMiddleOReach or ballBottomOReach:
    currStateOuter = "ballOReach"


  let
    isAbove = 0 < yi and yi <= ABOVE
    isBelow = yi >= BELOW and yi < ScreenH
    isLevel = yi >= LEVEL - (PADDLE_HEIGHT div 2) and yi < LEVEL + (PADDLE_HEIGHT div 2)


  if isAbove:
    currStateInner = "above"
  elif isBelow:
    currStateInner = "below"
  elif isLevel:
    currStateInner = "level"


const 
  REWARD_POS = 100.0
  REWARD_NEG = -120.0

  LEARNING_RATE = 0.0002
  DISCOUNT_RATE = 0.02


proc getMaxReward(): float =
  let currState = actionStateTable[currStateOuter][currStateInner].state
  var list: seq[float] = @[currState.goDown, currState.goUp, currState.doNothing]

  return max(list)


proc qUpdate(value, rew: float): float =
  result = value + (LEARNING_RATE * (rew + DISCOUNT_RATE * getMaxReward() - value))


proc goUpAdd() =
  var reward =  qUpdate(actionStateTable[currStateOuter][currStateInner].state.goUp, REWARD_POS)
  actionStateTable[currStateOuter][currStateInner].state.goUp = reward

  var rewardStr = reward.formatFloat(ffDecimal, 4)
  echo(fmt"Rewarded pos {rewardStr}  to states:  {currStateOuter}  ---   {currStateInner} for going up")

proc goDownAdd() =
  var reward = qUpdate(actionStateTable[currStateOuter][currStateInner].state.goDown, REWARD_POS)
  actionStateTable[currStateOuter][currStateInner].state.goDown = reward

  var rewardStr = reward.formatFloat(ffDecimal, 4)
  echo(fmt"Rewarded pos {rewardStr}  to states:  {currStateOuter}  ---   {currStateInner} for going down")

proc doNothinAdd() =
  var reward = qUpdate(actionStateTable[currStateOuter][currStateInner].state.doNothing, REWARD_POS)
  actionStateTable[currStateOuter][currStateInner].state.doNothing = reward

  var rewardStr = reward.formatFloat(ffDecimal, 4)
  echo(fmt"Rewarded pos {rewardStr}  to states:  {currStateOuter}  ---   {currStateInner} for doing nothing")


proc goUpASub() =
  var reward = qUpdate(actionStateTable[currStateOuter][currStateInner].state.goUp, REWARD_NEG)
  actionStateTable[currStateOuter][currStateInner].state.goUp = reward

  var rewardStr = reward.formatFloat(ffDecimal, 4)
  echo(fmt"Rewarded neg {rewardStr}  to states:  {currStateOuter}  ---   {currStateInner} for going up")

proc goDownSub() =
  var reward = qUpdate(actionStateTable[currStateOuter][currStateInner].state.goDown, REWARD_NEG)
  actionStateTable[currStateOuter][currStateInner].state.goDown = reward

  var rewardStr = reward.formatFloat(ffDecimal, 4)
  echo(fmt"Rewarded neg {rewardStr}  to states:  {currStateOuter}  ---   {currStateInner} for going down")

proc doNothinSub() =
  var reward = qUpdate(actionStateTable[currStateOuter][currStateInner].state.doNothing, REWARD_NEG)
  actionStateTable[currStateOuter][currStateInner].state.doNothing = reward

  var rewardStr = reward.formatFloat(ffDecimal, 4)
  echo(fmt"Rewarded neg {rewardStr}  to states:  {currStateOuter}  ---   {currStateInner} for doing nothing")


proc assertAction() =
  if xi >= ScreenW div 4 or didBouncePlayer:
    return

  getState()

  var 
    currState = actionStateTable[currStateOuter][currStateInner].state
    args: seq[float] = @[currState.doNothing, currState.goDown, currState.goUp]

    ind = 0
    val = args[0]

  for i, v in enumerate(args):
    if v >= val:
      val = v
      ind = i

  if ind == 0:
    actionDo = possiblePlayerActions.doNothing
  elif ind == 1:
    actionDo = possiblePlayerActions.goDown
  else:
    actionDo = possiblePlayerActions.goUp


proc rewardState() =
  if stateOfGameBuffer[0] != stateOfGameBuffer[1]:
    if stateOfGameBuffer[1] == gameState.playerLost:
      if actionDo == possiblePlayerActions.doNothing:
        doNothinSub()
      elif actionDo == possiblePlayerActions.goDown:
        goDownSub()
      elif actionDo == possiblePlayerActions.goUp:
        goUpASub()

    elif stateOfGameBuffer[1] == gameState.opponentLost:
      if actionDo == possiblePlayerActions.doNothing:
        doNothinAdd()
      elif actionDo == possiblePlayerActions.goDown:
        goDownAdd()
      elif actionDo == possiblePlayerActions.goUp:
        goUpAdd()

if init(app):
    while not done:

        done = events(pressed)
        
        xSpeed<->ySpeed
        xi?>yi
        +->opponentPaddleDir

        drawBall(app)

        drawMiddleLine(app)

        assertAction()
        controlPlayerPaddle()

        drawOpponentPaddle(app)
        drawPlayerPaddle(app)
        
        calculateStateOfGame()
        rewardState()

        >>app


# Shutdown
exit(app)