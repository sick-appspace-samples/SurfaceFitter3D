
--Start of Global Scope---------------------------------------------------------

local DELAY = 1000 -- ms between visualization steps for demonstration purpose

-- Creating viewer instances
local viewer3D = View.create("viewer3D1")

local viewer2D = View.create("viewer2D1")

-- Cyan color scheme for search regions
local searchRegionDecoration = View.PixelRegionDecoration.create()
searchRegionDecoration:setColor(0, 255, 255, 60)

local searchDecoration = View.ShapeDecoration.create():setLineWidth(3)
searchDecoration:setFillColor(0, 255, 255, 80):setLineColor(0, 255, 255)

-- Green color scheme for fitted rectangles using ransac.
local foundDecoration = View.ShapeDecoration.create():setLineWidth(3)
foundDecoration:setFillColor(0, 255, 0, 120):setLineColor(0, 255, 0)

local imgDecoration = View.ImageDecoration.create()
imgDecoration:setRange(103, 145)

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
local hmViewId = 'Image1'

--End of Global Scope-----------------------------------------------------------

--Start of Function and Event Scope---------------------------------------------

---@param hm Image
---@return Shape3D
local function findObjectBasePlane(hm)
  -- The main plane of the object is located around 111 mm above the
  -- zero level. The surronding flat surfaces are at around 106 mm.
  local plane = sf:fitPlane(hm, nil, {108, 115})
  return plane
end

---@param fitter Image.SurfaceFitter
---@param hm Image
---@param box Shape3D
---@return Shape3D
local function findRectangleInBox(fitter, hm, box)
  -- Project the shape to the xy-plane, and note the extent in z.
  -- Fit a rectangle to that part of the heightmap.
  local boxRegion, boxMinZ, boxMaxZ = box:toPixelRegion(hm)
  local rect = fitter:fitRectangle(hm, boxRegion, {boxMinZ, boxMaxZ}, true)

  -- Updating view
  viewer2D:addPixelRegion(boxRegion, searchRegionDecoration)
  viewer2D:present()

  viewer3D:addShape(box, searchDecoration)
  viewer3D:addShape(rect, foundDecoration)
  viewer3D:present()

  Script.sleep(DELAY) -- for demonstration purpose only
  return rect
end

---@param hm Image
---@param searchBaseRect Shape3D
---@return Shape3D
local function findUpperRectangle(hm, searchBaseRect)
  -- Finding areas 3 to 10 mm above the plane of the searchBaseRect.
  local upperRegion = Image.thresholdPlane(hm, 3, 10, searchBaseRect:toPlane())

  -- Extracting the projected area of the search rectangle.
  local rectRegion = searchBaseRect:toPixelRegion(hm)

  -- Fitting a new rectangle to their intersection.
  local upperRect = sf:fitRectangle(hm, upperRegion:getIntersection(rectRegion), nil, false)

  -- Updating View
  viewer2D:addPixelRegion(upperRegion, searchRegionDecoration)
  viewer2D:addPixelRegion(rectRegion, searchRegionDecoration)
  viewer2D:present()

  viewer3D:addShape(searchBaseRect, searchDecoration)
  viewer3D:addShape(upperRect, foundDecoration)
  viewer3D:present()

  Script.sleep(DELAY) -- for demonstration purpose only
  return upperRect
end

---@param base Shape3D
---@param tilted Shape3D
---@param tiltedLS Shape3D
---@param upper Shape3D
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
  viewer2D:addImage(heightmap)
  viewer2D:present()

  viewer3D:clear()
  viewer3D:addHeightmap( {heightmap, intensitymap}, {imgDecoration}, {'Reflectance'}, hmViewId )
  viewer3D:present()
  Script.sleep(DELAY) -- for demonstration purpose only

  -- Define search area boxes for the tilted planes.
  local searchBox1 = Shape3D.createBox(35, 35, 20, Transform.createTranslation3D(30, 93, 128))
  local searchBox2 = Shape3D.createBox(35, 35, 24, Transform.createTranslation3D(-38, 93, 130))

  -- Fit planes and rectangles
  local basePlane = findObjectBasePlane(heightmap)
  viewer3D:addShape(basePlane, foundDecoration)
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
