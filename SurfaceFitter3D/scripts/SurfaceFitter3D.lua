--[[----------------------------------------------------------------------------

  Application Name:
  SurfaceFitter3D

  Summary:
  Fitting planes and rectangles to surfaces in heightmaps

  Description:
  This Sample shows how to use PixelRegions and 3D shapes to select points for fitting.
  Rectangles are fitted to different sets of points and the angle between planes is
  calculated. The use of a plane as reference for the threshold function is illustrated.

  How to Run:
  Starting this sample is possible either by running the app (F5) or
  debugging (F7+F10). Setting breakpoint on the first row inside the 'main'
  function allows debugging step-by-step after 'Engine.OnStarted' event.
  Results can be seen in the 3D viewer and 2D viewer on the DevicePage.
  Select Reflectance in the View: box at the top of the GUI and zoom in on the
  data for best experience.
  Restarting the Sample may be necessary to show the heightmap after loading the webpage.
  To run this Sample a device with SICK Algorithm API and AppEngine >= V2.5.0 is
  required. For example SIM4000 with latest firmware. Alternatively the Emulator
  on AppStudio 2.3 or higher can be used.

  More Information:
  Tutorial "Algorithms - Fitting and Measurement".

------------------------------------------------------------------------------]]
--Start of Global Scope---------------------------------------------------------

local DELAY = 1000 -- ms between visualization steps for demonstration purpose

-- Creating viewer instances
local viewer3D = View.create()
viewer3D:setID('viewer3D')

local viewer2D = View.create()
viewer2D:setID('viewer2D')

-- Cyan color scheme for search regions
local searchRegionDecoration = View.PixelRegionDecoration.create()
searchRegionDecoration:setColor(0, 255, 255, 60)

local searchDecoration = View.ShapeDecoration.create()
searchDecoration:setFillColor(0, 255, 255, 80)
searchDecoration:setLineColor(0, 255, 255)
searchDecoration:setLineWidth(3)

-- Green color scheme for fitted rectangles using ransac.

local foundDecoration = View.ShapeDecoration.create()
foundDecoration:setFillColor(0, 255, 0, 120)
foundDecoration:setLineColor(0, 255, 0)
foundDecoration:setLineWidth(3)

-- Create surface fitter. Set fit mode to RANSAC to be robust
-- against outliers. Set the margin to 0.25 mm, based on the
-- observed noise in the heightmap.
local sf = Image.SurfaceFitter.create()
sf:setFitMode('RANSAC')
sf:setOutlierMargin(0.25, 'ABSOLUTE')

-- Create least-squares surface fitter for comparison.
local sfls = Image.SurfaceFitter.create()
sfls:setFitMode('LEASTSQUARES')

--Setting specific view ID for iconics in viewer
local imViewId = 'Heightmap1'
local hmViewId = 'Image1'

--End of Global Scope-----------------------------------------------------------

--Start of Function and Event Scope---------------------------------------------

--@findObjectBasePlane(hm:Image) : Shape3D
local function findObjectBasePlane(hm)
  -- The main plane of the object is located around 111 mm above the
  -- zero level. The surronding flat surfaces are at around 106 mm.
  local plane = sf:fitPlane(hm, nil, {108, 115})
  return plane
end

-- @findRectangleInBox(fitter:Image.SurfaceFitter, hm:Image, box:Shape3D) : Shape3D
local function findRectangleInBox(fitter, hm, box)
  -- Project the shape to the xy-plane, and note the extent in z.
  -- Fit a rectangle to that part of the heightmap.
  local boxRegion, boxMinZ, boxMaxZ = box:toPixelRegion(hm)
  local rect = fitter:fitRectangle(hm, boxRegion, {boxMinZ, boxMaxZ}, true)

  -- Updating view
  viewer2D:addPixelRegion(boxRegion, searchRegionDecoration, nil, imViewId)
  viewer2D:present()

  viewer3D:addShape(box, searchDecoration, nil, hmViewId)
  viewer3D:addShape(rect, foundDecoration, nil, hmViewId)
  viewer3D:present()

  Script.sleep(DELAY) -- for demonstration purpose only
  return rect
end

-- @findUpperRectangle(hm:Image, searchBaseRect:Shape3D) : Shape3D
local function findUpperRectangle(hm, searchBaseRect)
  -- Finding areas 3 to 10 mm above the plane of the searchBaseRect.
  local upperRegion = Image.thresholdPlane(hm, 3, 10, searchBaseRect:toPlane())

  -- Extracting the projected area of the search rectangle.
  local rectRegion = searchBaseRect:toPixelRegion(hm)

  -- Fitting a new rectangle to their intersection.
  local upperRect = sf:fitRectangle(hm, upperRegion:getIntersection(rectRegion), nil, false)

  -- Updating View
  viewer2D:addPixelRegion(upperRegion, searchRegionDecoration, nil, imViewId)
  viewer2D:addPixelRegion(rectRegion, searchRegionDecoration, nil, imViewId)
  viewer2D:present()

  viewer3D:addShape(searchBaseRect, searchDecoration, nil, hmViewId)
  viewer3D:addShape(upperRect, foundDecoration, nil, hmViewId)
  viewer3D:present()

  Script.sleep(DELAY) -- for demonstration purpose only
  return upperRect
end

-- @printPlaneTilt(base:Shape3D, tilted:Shape3D, tiltedLS:Shape3D, upper:Shape3D)
local function printPlaneTilt(base, tilted, tiltedLS, upper)
  local basePlaneTilt = base:getIntersectionAngle(Shape3D.createPlane(0, 0, 1, 0))
  local tiltedToBaseRad = tilted:getIntersectionAngle(base)
  local upperToTiltedRad = upper:getIntersectionAngle(tilted)
  local tiltedLsToBaseRad = tiltedLS:getIntersectionAngle(base)

  print(
    'Slope of base plane relative to xy-plane: ' ..
    tostring(math.deg(basePlaneTilt)) .. ' degrees.)'
  )
  print(
    'Slope of green tilted plane (base plane reference): ' ..
    tostring(math.deg(tiltedToBaseRad)) .. ' degrees.'
  )
  print(
    'Slope of green top plane (tilted plane reference): ' ..
    tostring(math.deg(upperToTiltedRad)) .. ' degrees.'
  )
  print(
    'Slope of yellow tilted plane (base plane reference): ' ..
    tostring(math.deg(tiltedLsToBaseRad)) .. ' degrees.'
  )
end


local function main()
  -- Loading heightmap from resources.
  local images = Object.load('resources/image.json')
  local heightmap = images[1]
  local intensitymap = images[2]

  -- Updating views
  viewer2D:clear()
  viewer2D:addImage(heightmap, nil, imViewId)
  viewer2D:present()

  viewer3D:clear()
  viewer3D:addHeightmap( {heightmap, intensitymap}, {}, {'Reflectance'}, hmViewId )
  viewer3D:present()
  Script.sleep(DELAY) -- for demonstration purpose only

  -- Define search area boxes for the tilted planes.
  local searchBox1 = Shape3D.createBox(35, 35, 20, Transform.createTranslation3D(30, 93, 128))
  local searchBox2 = Shape3D.createBox(35, 35, 24, Transform.createTranslation3D(-38, 93, 130))

  -- Fit planes and rectangles
  local basePlane = findObjectBasePlane(heightmap)
  viewer3D:addShape(basePlane, foundDecoration, nil, hmViewId)
  viewer3D:present()
  Script.sleep(DELAY) -- for demonstration purpose only

  local slopeRect = findRectangleInBox(sf, heightmap, searchBox1)
  local slopeRectLeastSquares = findRectangleInBox(sfls, heightmap, searchBox2)
  local upperRect = findUpperRectangle(heightmap, slopeRect)

  -- Printing intersection angles
  printPlaneTilt(basePlane, slopeRect, slopeRectLeastSquares, upperRect)

  print('App finished.')
end
--The following registration is part of the global scope which runs once after startup
--Registration of the 'main' function to the 'Engine.OnStarted' event
Script.register('Engine.OnStarted', main)

--End of Function and Event Scope--------------------------------------------------
