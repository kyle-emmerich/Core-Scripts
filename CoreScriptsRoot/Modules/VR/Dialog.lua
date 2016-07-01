--Dialog: 3D dialogs for ROBLOX in VR
--written by 0xBAADF00D
--6/30/2016

local CoreGui = game:GetService("CoreGui")
local RobloxGui = CoreGui:WaitForChild("RobloxGui")
local InputService = game:GetService("UserInputService")
local Utility = require(RobloxGui.Modules.Utility)
local Panel3D = require(RobloxGui.Modules.VR.Panel3D)

local DIALOG_BG_COLOR = Color3.new(0.2, 0.2, 0.2)
local DIALOG_BG_TRANSPARENCY = 0.3

local TITLE_COLOR = Color3.new(1, 1, 1)

local DIALOG_TITLE_HEIGHT = 66
local DIALOG_COLOR_HEIGHT = 8
local DIALOG_TITLE_TEXT_SIZE = Enum.FontSize.Size36

local DIALOG_CONTENT_PADDING = 48

local emptySelectionImage = Utility.Create "ImageLabel" { Image = "", BackgroundTransparency = 1, ImageTransparency = 1 }

local PANEL_OFFSET_CF = CFrame.new(0, 0, -7)* CFrame.Angles(0, math.pi, 0)

local DialogPanel = Panel3D.Get("Dialog")
DialogPanel:SetType(Panel3D.Type.Fixed)
DialogPanel.localCF = PANEL_OFFSET_CF
DialogPanel:SetCanFade(true)

local dialogPanelAngle = 0

local PANEL_FADE_ANGLE_0, PANEL_FADE_ANGLE_1 = math.rad(30), math.rad(40)
local PANEL_FADE_RANGE = PANEL_FADE_ANGLE_1 - PANEL_FADE_ANGLE_0
local PANEL_REAPPEAR_ANGLE = math.rad(90)

local function positionDialogPanel(desiredAngle)
	dialogPanelAngle = desiredAngle
	local headCF = InputService:GetUserCFrame(Enum.UserCFrame.Head)
	local headPos = headCF.p
	DialogPanel.localCF = CFrame.new(headPos) * CFrame.Angles(0, desiredAngle, 0) * PANEL_OFFSET_CF
end

function DialogPanel:CalculateTransparency()
	local headCF = InputService:GetUserCFrame(Enum.UserCFrame.Head)
	local headLook = headCF.lookVector * Vector3.new(1, 0, 1)
	local vectorToPanel = Vector3.new(math.cos(dialogPanelAngle + math.rad(90)), 0, -math.sin(dialogPanelAngle + math.rad(90)))

	local angleToPanel = math.acos(headLook:Dot(vectorToPanel))
	return math.min(math.max(0, (angleToPanel - PANEL_FADE_ANGLE_0) / PANEL_FADE_RANGE), 1)
end


local opacityLookup = {}

game:GetService("RunService"):BindToRenderStep("DialogPanel", Enum.RenderPriority.Last.Value, function()
	if DialogPanel.transparency == 1 then
		local headCF = InputService:GetUserCFrame(Enum.UserCFrame.Head)
		local headLook = headCF.lookVector * Vector3.new(1, 0, 1)
		local headAngle = (math.atan2(-headLook.Z, headLook.X) - math.rad(90)) % math.rad(360)
		local newPanelAngle = math.floor((headAngle / PANEL_REAPPEAR_ANGLE) + 0.5) * PANEL_REAPPEAR_ANGLE
		positionDialogPanel(newPanelAngle)
	end

	--update the transparency of gui elements
	local opacityMult = 1 - DialogPanel.transparency
	for guiElement, baseOpacity in pairs(opacityLookup) do
		local transparency = 1 - (baseOpacity * opacityMult)
		if guiElement:IsA("TextLabel") then
			guiElement.TextTransparency = transparency
		elseif guiElement:IsA("ImageLabel") then
			guiElement.ImageTransparency = transparency
		end
	end
end)

local DialogQueue = {}

local function updatePanel()
	local currentDialog = DialogQueue[1]
	if not currentDialog or not currentDialog.content then
		DialogPanel:GetGUI():ClearAllChildren()
		DialogPanel:SetVisible(false)
		opacityLookup = {}
	else
		local gui = DialogPanel:GetGUI()
		currentDialog.content.Parent = nil
		gui:ClearAllChildren()

		local frame = Utility.Create "Frame" {
			Parent = gui,
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(1, 0, 1, 0),

			Active = true,

			BackgroundTransparency = 1
		}
		local frameBackground = Utility.Create "ImageLabel" {
			Parent = frame,
			Name = "FrameBackground",
			Position = UDim2.new(0, -1, 0, -1),
			Size = UDim2.new(1, 2, 1, 2),

			BackgroundTransparency = 1,
			Image = "rbxasset://textures/ui/VR/rectBackgroundWhite.png",
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(10, 10, 10, 10),

			ImageColor3 = DIALOG_BG_COLOR,
			ImageTransparency = DIALOG_BG_TRANSPARENCY
		}
		local dialogTitle = Utility.Create "TextLabel" {
			Parent = frame,
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(1, 0, 0, DIALOG_TITLE_HEIGHT),

			BackgroundTransparency = 1,
			Text = currentDialog.titleText,
			TextColor3 = TITLE_COLOR,
			Font = Enum.Font.SourceSansBold,
			FontSize = DIALOG_TITLE_TEXT_SIZE
		}
		local dialogColor = Utility.Create "ImageLabel" {
			Parent = frame,
			Position = UDim2.new(0, -1, 0, -1 + DIALOG_TITLE_HEIGHT),
			Size = UDim2.new(1, 2, 0, 2 + DIALOG_COLOR_HEIGHT),

			BackgroundTransparency = 1,
			Image = "rbxasset://textures/ui/VR/rectBackgroundWhite.png",
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(10, 10, 10, 10),

			ImageColor3 = currentDialog.color,
		}

		local content = Utility.Create "Frame" {
			Parent = frame,
			Position = UDim2.new(0, DIALOG_CONTENT_PADDING, 0, DIALOG_TITLE_HEIGHT + DIALOG_COLOR_HEIGHT + DIALOG_CONTENT_PADDING),
			Size = UDim2.new(1, -DIALOG_CONTENT_PADDING * 2, 1, -DIALOG_TITLE_HEIGHT - DIALOG_COLOR_HEIGHT - (DIALOG_CONTENT_PADDING * 2)),

			BackgroundTransparency = 1
		}

		currentDialog.content.Parent = content
		local contentHeight = currentDialog.content.AbsoluteSize.Y
		DialogPanel:ResizePixels(640, DIALOG_TITLE_HEIGHT + DIALOG_COLOR_HEIGHT + contentHeight, 250)
		DialogPanel:SetVisible(true)

		opacityLookup = {}
		local function search(parent)
			if parent:IsA("ImageLabel") then
				opacityLookup[parent] = 1 - parent.ImageTransparency
			elseif parent:IsA("TextLabel") then
				opacityLookup[parent] = 1 - parent.TextTransparency
			end
			for i, v in pairs(parent:GetChildren()) do
				search(v)
			end
		end
		search(DialogPanel:GetGUI())
	end
end



local Dialog = {}
Dialog.__index = Dialog
function Dialog.new(titleText, color)
	local self = setmetatable({}, Dialog)
	self.titleText = titleText
	self.color = color
	self.content = nil
	return self
end

function Dialog:SetContent(guiElement)
	if not guiElement and self.content then
		self.content.Parent = nil
	end
	self.content = guiElement
end

function Dialog:Show(shouldTakeover)
	if shouldTakeover then
		table.insert(DialogQueue, 1, self)
	else
		table.insert(DialogQueue, self)
	end
	updatePanel()
end

function Dialog:Close()
	for idx, dialog in pairs(DialogQueue) do
		if dialog == self then
			table.remove(DialogQueue, idx)
			break
		end
	end
	updatePanel()
end

return Dialog