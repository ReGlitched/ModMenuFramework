global function UICodeCallback_modmenu_ModInit
global function InitModMenu
global function SetupModCommand // for dev
global function SetupModFunc // for dev
global function SetupModMenu //for dev
global function RepeatLastModCommand
global function UpdatePrecachedSPWeapons_MOD
global function ServerCallback_OpenModMenu
global function RunCodeModCommandByAlias
global function DEV_InitCodeModMenu
global function UpdateModMenuButtons
global function ChangeToThisModMenu
global function PushModPageHistory
global function AddLeveModCommand
global function GetCheatsStateMod
global function RegisterModMenu
global function SetupRegisteredModMenus
global function SetModMenu_Root
global function GenericModMenu_Navigate
global function OpenModMenu

const string DEV_MENU_NAME = "[LEVEL]"

global struct ModMenuPage
{
	void functionref()      devMenuFunc
	void functionref( var ) devMenuFuncWithOpParm
	var                     devMenuOpParm
}

global struct DevModCommand
{
	string                  label
	string                  command
	var                     opParm
	void functionref( var ) func
	bool                    isAMenuCommand = false
}

global struct ModSubMenu
{
	string          label
	void functionref() setupFunc
}

global struct ModMenuStruct
{
	array<ModMenuPage> pageHistory = []
	array<string>      pagePath = []
	ModMenuPage &      currentModPage
	var                header
	array<var>         buttons
	array<table>       actionBlocks
	array<DevModCommand>  devModCommands
	DevModCommand&        lastDevModCommand
	bool               lastDevModCommandAssigned
	string             lastDevModCommandLabel
	bool               precachedWeapons
	DevModCommand& focusedCmd
	bool        focusedCmdIsAssigned
	var footerHelpTxtLabel
	bool                      initializingCodeDevMenu = false
	string                    codeDevMenuPrefix = DEV_MENU_NAME + "/"
	table<string, DevModCommand> codeDevMenuCommands
	array<DevModCommand> levelSpecificCommands = []
	bool cheatsState
}

global array<ModSubMenu> registeredModSubMenus
global ModMenuStruct modMenuStruct
global table<string, void functionref()> g_modMenuClickHandlers

void function RegisterModMenu( string label, void functionref() setupFunc )
{
	ModSubMenu menu
	menu.label = label
	menu.setupFunc = setupFunc
	registeredModSubMenus.append( menu )
}

bool function GetCheatsStateMod()
{
	return true //temp
}

void function UICodeCallback_modmenu_ModInit()
{
	AddUICallback_OnInitMenus( void function() {
		AddMenu( "ModMenu", $"scripts/resource/ui/menus/mod_menu.menu", InitModMenu, "ModMenu" )
	} )
}

void function InitModMenu( var newMenuArg )
{
	var menu = GetMenu( "ModMenu" )
	AddMenuEventHandler( menu, eUIEvent.MENU_OPEN, OnOpenModMenu )
	modMenuStruct.header = Hud_GetChild( menu, "MenuTitle" )
	modMenuStruct.buttons = GetElementsByClassname( menu, "DevButtonClass" )
	foreach ( button in modMenuStruct.buttons )
	{
		Hud_AddEventHandler( button, UIE_CLICK, OnModButton_Activate )
		Hud_AddEventHandler( button, UIE_GET_FOCUS, OnModButton_GetFocus )
		Hud_AddEventHandler( button, UIE_GET_FOCUS, OnModButton_LoseFocus )
		RuiSetString( Hud_GetRui( button ), "buttonText", "" )
		Hud_SetEnabled( button, false )
	}
	AddMenuFooterOption( menu, LEFT, BUTTON_B, true, "%[B_BUTTON|]% Back", "Back" )
	AddMenuEventHandler( menu, eUIEvent.MENU_NAVIGATE_BACK, BackOneModPage_Activate )
	AddMenuFooterOption( menu, LEFT, BUTTON_Y, true, "%[Y_BUTTON|]% Repeat Last Command:", "Repeat Last Command:", RepeatLastModCommand_Activate )
	modMenuStruct.footerHelpTxtLabel = GetElementsByClassname( menu, "FooterHelpTxt" )[0]
	
	RegisterSignal( "DEV_InitCodeModMenu" )
	AddUICallback_LevelLoadingFinished( DEV_InitCodeModMenu )
	AddUICallback_LevelShutdown( ClearCodeModMenu )

	var systemPanel = GetPanel( "SystemPanel" )
    AddPanelFooterOption( systemPanel, RIGHT, BUTTON_X, true, "#Y_BUTTON_DEV_MENU", "Mod Menu", OpenModMenu, ShouldShowModMenu )

	var inventoryPanel = GetPanel( "SurvivalQuickInventoryPanel" )
    AddPanelFooterOption( inventoryPanel, RIGHT, BUTTON_X, true, "#Y_BUTTON_DEV_MENU", "Mod Menu", OpenModMenu, ShouldShowModMenu )
}

void function OpenModMenu( var button )
{
	AdvanceMenu( GetMenu( "ModMenu" ) )
}

void function AddLeveModCommand( string label, string command )
{
	string codeDevMenuAlias = DEV_MENU_NAME + "/" + label
	DevMenu_Alias_DEV( codeDevMenuAlias, command )
	DevModCommand cmd
	cmd.label = label
	cmd.command = command
	modMenuStruct.levelSpecificCommands.append( cmd )
}

void function OnOpenModMenu()
{
	g_modMenuClickHandlers.clear()
	modMenuStruct.pageHistory.clear()
	modMenuStruct.pagePath.clear()
	modMenuStruct.currentModPage.devMenuFunc = null
	modMenuStruct.currentModPage.devMenuFuncWithOpParm = null
	modMenuStruct.currentModPage.devMenuOpParm = null
	SetModMenu_Root()
}

void function SetModMenu_Root()
{
	if ( modMenuStruct.initializingCodeDevMenu )
	{
		SetupDefaultModCommands()
		return
	}
	PushModPageHistory()
	modMenuStruct.currentModPage.devMenuFunc = SetupDefaultModCommands
	UpdateModMenuButtons()
}

void function ServerCallback_OpenModMenu()
{
	AdvanceMenu( GetMenu( "ModMenu" ) )
}

void function DEV_InitCodeModMenu()
{
	thread DEV_InitCodeModMenu_Internal()
}

void function DEV_InitCodeModMenu_Internal()
{
	Signal( uiGlobal.signalDummy, "DEV_InitCodeModMenu" )
	EndSignal( uiGlobal.signalDummy, "DEV_InitCodeModMenu" )
	while ( !IsFullyConnected() || !IsItemFlavorRegistrationFinished() )
	{
		WaitFrame()
	}
	modMenuStruct.initializingCodeDevMenu = true
	DevMenu_Alias_DEV( DEV_MENU_NAME, "" )
	DevMenu_Rm_DEV( DEV_MENU_NAME )
	OnOpenModMenu()
	modMenuStruct.initializingCodeDevMenu = false
}

void function ClearCodeModMenu()
{
	DevMenu_Alias_DEV( DEV_MENU_NAME, "" )
	DevMenu_Rm_DEV( DEV_MENU_NAME )
}

void function UpdateModMenuButtons()
{
	modMenuStruct.devModCommands.clear()
	if ( modMenuStruct.initializingCodeDevMenu )
		return

	{
		string titleText = "Mod Menu"
		foreach ( string pageName in modMenuStruct.pagePath )
		{
			titleText += " > " + pageName
		}
		Hud_SetText( modMenuStruct.header, titleText )
	}

	if ( modMenuStruct.currentModPage.devMenuOpParm != null )
		modMenuStruct.currentModPage.devMenuFuncWithOpParm( modMenuStruct.currentModPage.devMenuOpParm )
	else
		modMenuStruct.currentModPage.devMenuFunc()
	foreach ( index, button in modMenuStruct.buttons )
	{
		int buttonID = int( Hud_GetScriptID( button ) )
		if ( buttonID < modMenuStruct.devModCommands.len() )
		{
			RuiSetString( Hud_GetRui( button ), "buttonText", modMenuStruct.devModCommands[buttonID].label )
			Hud_SetEnabled( button, true )
		}
		else
		{
			RuiSetString( Hud_GetRui( button ), "buttonText", "" )
			Hud_SetEnabled( button, false )
		}
		if ( buttonID == 0 )
			Hud_SetFocused( button )
	}
	RefreshRepeatLastModCommandPrompts()
}

void function ChangeToThisModMenu( void functionref() menuFunc )
{
	if ( modMenuStruct.initializingCodeDevMenu )
	{
		menuFunc()
		return
	}
	PushModPageHistory()
	modMenuStruct.currentModPage.devMenuFunc = menuFunc
	modMenuStruct.currentModPage.devMenuFuncWithOpParm = null
	modMenuStruct.currentModPage.devMenuOpParm = null
	UpdateModMenuButtons()
}

void function ChangeToThisModMenu_WithOpParm( void functionref( var ) menuFuncWithOpParm, var opParm )
{
	if ( modMenuStruct.initializingCodeDevMenu )
	{
		menuFuncWithOpParm( opParm )
		return
	}
	PushModPageHistory()
	modMenuStruct.currentModPage.devMenuFunc = null
	modMenuStruct.currentModPage.devMenuFuncWithOpParm = menuFuncWithOpParm
	modMenuStruct.currentModPage.devMenuOpParm = opParm
	UpdateModMenuButtons()
}

void function SetupDefaultModCommands()
{
	RunClientScript("DEV_SendCheatsStateToUI")
	if ( GetCheatsStateMod() )
	{
		if ( registeredModSubMenus.len() > 0 )
		{
			g_modMenuClickHandlers.clear()
			foreach ( ModSubMenu modMenu in registeredModSubMenus )
			{
				g_modMenuClickHandlers[modMenu.label] <- modMenu.setupFunc
			}
			foreach ( ModSubMenu modMenu in registeredModSubMenus )
			{
				SetupModMenu( modMenu.label, GenericModMenu_Navigate, modMenu.label )
			}
		}
		else
		{
			SetupModCommand( "No mods are installed or they do not support this menu.", "empty" )
		}
	}
	else
	{
		SetupModCommand( "Cheats are disabled! Type 'sv_cheats 1' in console to enable dev menu if you're the server admin.", "empty" )
	}
}

void function GenericModMenu_Navigate( var opParm )
{
	string key = "" + opParm
	void functionref() setupFunc = g_modMenuClickHandlers[key]
	ChangeToThisModMenu( setupFunc )
}

void function SetupRegisteredModMenus( var _ )
{
	foreach ( ModSubMenu modMenu in registeredModSubMenus )
	{
		SetupModMenu( modMenu.label, GenericModMenu_Navigate, modMenu.label )
	}
}

void function ChangeToThisModMenu_PrecacheWeapons( void functionref() menuFunc )
{
	if ( modMenuStruct.initializingCodeDevMenu )
	{
		menuFunc()
		return
	}
	waitthread PrecacheWeaponsIfNecessary()
	PushModPageHistory()
	modMenuStruct.currentModPage.devMenuFunc = menuFunc
	modMenuStruct.currentModPage.devMenuFuncWithOpParm = null
	modMenuStruct.currentModPage.devMenuOpParm = null
	UpdateModMenuButtons()
}

void function ChangeToThisModMenu_PrecacheWeapons_WithOpParm( void functionref( var ) menuFuncWithOpParm, var opParm )
{
	if ( modMenuStruct.initializingCodeDevMenu )
	{
		menuFuncWithOpParm( opParm )
		return
	}
	waitthread PrecacheWeaponsIfNecessary()
	PushModPageHistory()
	modMenuStruct.currentModPage.devMenuFunc = null
	modMenuStruct.currentModPage.devMenuFuncWithOpParm = menuFuncWithOpParm
	modMenuStruct.currentModPage.devMenuOpParm = opParm
	UpdateModMenuButtons()
}

void function PrecacheWeaponsIfNecessary()
{
	if ( modMenuStruct.precachedWeapons )
		return
	modMenuStruct.precachedWeapons = true
	CloseAllMenus()
	DisablePrecacheErrors()
	wait 0.1
	ClientCommand( "script PrecacheSPWeapons()" )
	wait 0.1
	ClientCommand( "script_client PrecacheSPWeapons()" )
	wait 0.1
	RestorePrecacheErrors()
	AdvanceMenu( GetMenu( "ModMenu" ) )
}

void function UpdatePrecachedSPWeapons_MOD()
{
	modMenuStruct.precachedWeapons = true
}

void function RunCodeModCommandByAlias( string alias )
{
	RunDevCommand( modMenuStruct.codeDevMenuCommands[alias], false )
}

void function SetupModCommand( string label, string command )
{
	if ( command.slice( 0, 5 ) == "give " )
		command = "give_server " + command.slice( 5 )
	DevModCommand cmd
	cmd.label = label
	cmd.command = command
	modMenuStruct.devModCommands.append( cmd )
	if ( modMenuStruct.initializingCodeDevMenu )
	{
		string codeDevMenuAlias = modMenuStruct.codeDevMenuPrefix + label
		DevMenu_Alias_DEV( codeDevMenuAlias, command )
	}
}

void function SetupModFunc( string label, void functionref( var ) func, var opParm = null )
{
	DevModCommand cmd
	cmd.label = label
	cmd.func = func
	cmd.opParm = opParm
	modMenuStruct.devModCommands.append( cmd )
	if ( modMenuStruct.initializingCodeDevMenu )
	{
		string codeDevMenuAlias   = modMenuStruct.codeDevMenuPrefix + label
		string codeDevMenuCommand = format( "script_ui RunCodeModCommandByAlias( \"%s\" )", codeDevMenuAlias )
		modMenuStruct.codeDevMenuCommands[codeDevMenuAlias] <- cmd
		DevMenu_Alias_DEV( codeDevMenuAlias, codeDevMenuCommand )
	}
}

void function SetupModMenu( string label, void functionref( var ) func, var opParm = null )
{
	DevModCommand cmd
	cmd.label = (label + "  ->")
	cmd.func = func
	cmd.opParm = opParm
	cmd.isAMenuCommand = true
	modMenuStruct.devModCommands.append( cmd )
	if ( modMenuStruct.initializingCodeDevMenu )
	{
		string codeDevMenuPrefix = modMenuStruct.codeDevMenuPrefix
		modMenuStruct.codeDevMenuPrefix += label + "/"
		cmd.func( cmd.opParm )
		modMenuStruct.codeDevMenuPrefix = codeDevMenuPrefix
	}
}

void function OnModButton_Activate( var button )
{
	if ( level.ui.disableDev )
	{
		Warning( "Dev commands disabled on matchmaking servers." )
		return
	}
	int buttonID   = int( Hud_GetScriptID( button ) )
	DevModCommand cmd = modMenuStruct.devModCommands[buttonID]

	if ( cmd.isAMenuCommand )
	{
		string menuName = cmd.label.slice( 0, cmd.label.len() - 3 )
		modMenuStruct.pagePath.append( menuName )
	}
	RunDevCommand( cmd, false )
}

void function OnModButton_GetFocus( var button )
{
	modMenuStruct.focusedCmdIsAssigned = false
	int buttonID = int( Hud_GetScriptID( button ) )
	if ( buttonID >= modMenuStruct.devModCommands.len() )
		return
	if ( modMenuStruct.devModCommands[buttonID].isAMenuCommand )
		return
	modMenuStruct.focusedCmd = modMenuStruct.devModCommands[buttonID]
	modMenuStruct.focusedCmdIsAssigned = true
}

void function OnModButton_LoseFocus( var button )
{
}

void function RunDevCommand( DevModCommand cmd, bool isARepeat )
{
	if ( !isARepeat && !cmd.isAMenuCommand )
	{
		modMenuStruct.lastDevModCommand = cmd
		modMenuStruct.lastDevModCommandAssigned = true

		string pathString = ""
		foreach ( int i, pageName in modMenuStruct.pagePath )
		{
			pathString += pageName + " > "
		}
		pathString += cmd.label
		modMenuStruct.lastDevModCommandLabel = pathString

		RefreshRepeatLastModCommandPrompts()
	}

	if ( cmd.command != "" )
	{
		ClientCommand( cmd.command )
		if ( IsLobby() )
		{
			CloseAllMenus()
			AdvanceMenu( GetMenu( "LobbyMenu" ) )
		}
	}
	else
	{
		cmd.func( cmd.opParm )
	}
}

void function RepeatLastModCommand( var _ )
{
	if ( !modMenuStruct.lastDevModCommandAssigned )
		return
	RunDevCommand( modMenuStruct.lastDevModCommand, true )
}

void function RepeatLastModCommand_Activate( var button )
{
	RepeatLastModCommand( null )
}

void function PushModPageHistory()
{
	ModMenuPage page = modMenuStruct.currentModPage
	if ( page.devMenuFunc != null || page.devMenuFuncWithOpParm != null )
		modMenuStruct.pageHistory.push( clone page )
}

void function BackOneModPage_Activate()
{
	if ( modMenuStruct.pageHistory.len() == 0 )
	{
		CloseActiveMenu( true )
		return
	}
	if ( modMenuStruct.pagePath.len() > 0 )
		modMenuStruct.pagePath.pop()

	modMenuStruct.currentModPage = modMenuStruct.pageHistory.pop()
	UpdateModMenuButtons()
}

void function RefreshRepeatLastModCommandPrompts()
{
	string newText = ""
	if ( modMenuStruct.lastDevModCommandAssigned )
		newText = modMenuStruct.lastDevModCommandLabel
	else
		newText = "<none>"

	Hud_SetText( modMenuStruct.footerHelpTxtLabel, newText )
}

void function SetupChangeSurvivalCharacterClass()
{
	array<ItemFlavor> characters = clone GetAllCharacters()
	characters.sort( int function( ItemFlavor a, ItemFlavor b ) {
		if ( Localize( ItemFlavor_GetLongName( a ) ) < Localize( ItemFlavor_GetLongName( b ) ) )
			return -1
		if ( Localize( ItemFlavor_GetLongName( a ) ) > Localize( ItemFlavor_GetLongName( b ) ) )
			return 1
		return 0
	} )
	foreach( ItemFlavor character in characters )
	{
		SetupModFunc( Localize( ItemFlavor_GetLongName( character ) ), void function( var unused ) : ( character ) {
			DEV_RequestSetItemFlavorLoadoutSlot( LocalClientEHI(), Loadout_CharacterClass(), character )
		} )
	}
}

bool function AreOnDefaultModCommandMenu()
{
	if ( modMenuStruct.currentModPage.devMenuFunc == SetupDefaultModCommands )
		return true
	if ( modMenuStruct.pageHistory.len() > 0 )
	{
		if ( modMenuStruct.pageHistory.top().devMenuFunc == SetupDefaultModCommands )
			return true
	}
	return false
}

bool function ShouldShowModMenu()
{
	if( IsLobby() )
		return false
	return true
}