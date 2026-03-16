package;

#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.addons.transition.FlxTransitionableState;
import flixel.effects.FlxFlicker;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import lime.app.Application;
import Achievements;
import editors.MasterEditorMenu;
import flixel.input.keyboard.FlxKey;

using StringTools;

class MainMenuState extends MusicBeatState
{
    // ========================= Static / Global Vars =========================
    public static var curSelected:Int = 0;
    
    // Dynamic engine version read from project.xml
    public static var psychEngineVersion:String = Application.current.meta.get('versionEngine') != null
        ? Application.current.meta.get('versionEngine')
        : "0.6.3"; // fallback if meta not set

    // ========================= Instance Vars =========================
    var menuItems:FlxTypedGroup<FlxSprite>;
    var camGame:FlxCamera;
    var camAchievement:FlxCamera;
    var camFollow:FlxObject;
    var camFollowPos:FlxObject;
    var magenta:FlxSprite;
    var debugKeys:Array<FlxKey>;
    var selectedSomething:Bool = false;

    var optionShit:Array<String> = [
        'story_mode',
        'freeplay',
        #if MODS_ALLOWED
        'mods',
        #end
        #if ACHIEVEMENTS_ALLOWED
        'awards',
        #end
        'credits',
        #if !switch
        'donate',
        #end
        'options'
    ];

    // ========================= Create Function =========================
    override function create()
    {
        #if MODS_ALLOWED
        Paths.pushGlobalMods();
        #end
        WeekData.loadTheFirstEnabledMod();

        #if DISCORD_ALLOWED
        DiscordClient.changePresence("In the Menus", null);
        #end

        debugKeys = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));

        // Setup cameras
        camGame = new FlxCamera();
        camAchievement = new FlxCamera();
        camAchievement.bgColor.alpha = 0;
        FlxG.cameras.reset(camGame);
        FlxG.cameras.add(camAchievement, false);
        FlxG.cameras.setDefaultDrawTarget(camGame, true);

        transIn = FlxTransitionableState.defaultTransIn;
        transOut = FlxTransitionableState.defaultTransOut;
        persistentUpdate = persistentDraw = true;

        // ================= Background =================
        var yScroll:Float = Math.max(0.25 - 0.05 * (optionShit.length - 4), 0.1);
        var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
        bg.scrollFactor.set(0, yScroll);
        bg.setGraphicSize(Std.int(bg.width * 1.175));
        bg.updateHitbox();
        bg.screenCenter();
        bg.antialiasing = ClientPrefs.globalAntialiasing;
        add(bg);

        // ================= Cam follow helpers =================
        camFollow = new FlxObject(0, 0, 1, 1);
        camFollowPos = new FlxObject(0, 0, 1, 1);
        add(camFollow);
        add(camFollowPos);

        // ================= Magenta overlay =================
        magenta = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
        magenta.scrollFactor.set(0, yScroll);
        magenta.setGraphicSize(Std.int(magenta.width * 1.175));
        magenta.updateHitbox();
        magenta.screenCenter();
        magenta.visible = false;
        magenta.antialiasing = ClientPrefs.globalAntialiasing;
        magenta.color = 0xFFfd719b;
        add(magenta);

        // ================= Menu Items =================
        menuItems = new FlxTypedGroup<FlxSprite>();
        add(menuItems);

        var scale:Float = 1;

        for (i in 0...optionShit.length)
        {
            var offset:Float = 108 - (Math.max(optionShit.length, 4) - 4) * 80;
            var menuItem:FlxSprite = new FlxSprite(0, i * 140 + offset);
            menuItem.scale.set(scale, scale);
            menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_' + optionShit[i]);
            menuItem.animation.addByPrefix('idle', optionShit[i] + " basic", 24);
            menuItem.animation.addByPrefix('selected', optionShit[i] + " white", 24);
            menuItem.animation.play('idle');
            menuItem.ID = i;
            menuItem.screenCenter(X);
            menuItems.add(menuItem);
            
            var scr:Float = Math.max(0, (optionShit.length - 4) * 0.135);
            menuItem.scrollFactor.set(0, scr);
            menuItem.antialiasing = ClientPrefs.globalAntialiasing;
            menuItem.updateHitbox();
        }

        FlxG.camera.follow(camFollowPos, null, 1);

        // ================= Version display =================
        addText(12, FlxG.height - 44, "Psych Engine v" + psychEngineVersion);
        addText(12, FlxG.height - 24, "Friday Night Funkin' v" + Application.current.meta.get('version'));

        // ================= Achievements =================
        #if ACHIEVEMENTS_ALLOWED
        Achievements.loadAchievements();
        checkFridayNightAchievement();
        #end

        // ================= Mobile touch controls =================
        #if mobile
        addTouchPad("UP_DOWN", "A_B_E");
        #end

        changeItem();
        super.create();
    }

    // ========================= Utility =========================
    private function addText(x:Float, y:Float, txt:String)
    {
        var t:FlxText = new FlxText(x, y, 0, txt);
        t.scrollFactor.set();
        t.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(t);
    }

    #if ACHIEVEMENTS_ALLOWED
    private function checkFridayNightAchievement()
    {
        var leDate = Date.now();
        if (leDate.getDay() == 5 && leDate.getHours() >= 18)
        {
            var achieveID:Int = Achievements.getAchievementIndex('friday_night_play');
            if (!Achievements.isAchievementUnlocked(Achievements.achievementsStuff[achieveID][2]))
            {
                Achievements.achievementsMap.set(Achievements.achievementsStuff[achieveID][2], true);
                giveAchievement();
                ClientPrefs.saveSettings();
            }
        }
    }

    private function giveAchievement()
    {
        add(new AchievementObject('friday_night_play', camAchievement));
        FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
        trace('Giving achievement "friday_night_play"');
    }
    #end

    // ========================= Update Loop =========================
    override function update(elapsed:Float)
    {
        // Smoothly increase music volume
        if (FlxG.sound.music.volume < 0.8)
        {
            FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
            if(FreeplayState.vocals != null) FreeplayState.vocals.volume += 0.5 * elapsed;
        }

        // Smooth camera lerp
        var lerpVal:Float = CoolUtil.boundTo(elapsed * 7.5, 0, 1);
        camFollowPos.setPosition(
            FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal),
            FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal)
        );

        handleInput();
        super.update(elapsed);

        // Keep menu items horizontally centered
        menuItems.forEach(function(spr:FlxSprite)
        {
            spr.screenCenter(X);
        });
    }

    // ========================= Input Handling =========================
    private function handleInput()
    {
        if (selectedSomething) return;

        if (controls.UI_UP_P)
        {
            FlxG.sound.play(Paths.sound('scrollMenu'));
            changeItem(-1);
        }
        if (controls.UI_DOWN_P)
        {
            FlxG.sound.play(Paths.sound('scrollMenu'));
            changeItem(1);
        }
        if (controls.BACK)
        {
            selectedSomething = true;
            FlxG.sound.play(Paths.sound('cancelMenu'));
            MusicBeatState.switchState(new TitleState());
        }

        #if mobile
        if (controls.ACCEPT) handleSelection();
        else if (touchPad.buttonE.justPressed || FlxG.keys.anyJustPressed(debugKeys))
        {
            selectedSomething = true;
            MusicBeatState.switchState(new MasterEditorMenu());
        }
        #else
        if (controls.ACCEPT) handleSelection();
        else if (FlxG.keys.anyJustPressed(debugKeys))
        {
            selectedSomething = true;
            MusicBeatState.switchState(new MasterEditorMenu());
        }
        #end
    }

    private function handleSelection()
    {
        var selectedOption = optionShit[curSelected];

        if (selectedOption == 'donate')
        {
            CoolUtil.browserLoad('https://ninja-muffin24.itch.io/funkin');
            return;
        }

        selectedSomething = true;
        FlxG.sound.play(Paths.sound('confirmMenu'));
        if(ClientPrefs.flashing) FlxFlicker.flicker(magenta, 1.1, 0.15, false);

        menuItems.forEach(function(spr:FlxSprite)
        {
            if (spr.ID != curSelected)
            {
                FlxTween.tween(spr, {alpha: 0}, 0.4, {ease: FlxEase.quadOut, onComplete: function(_) spr.kill()});
            }
            else
            {
                FlxFlicker.flicker(spr, 1, 0.06, false, false, function(_)
                {
                    switch(selectedOption)
                    {
                        case 'story_mode': MusicBeatState.switchState(new StoryMenuState());
                        case 'freeplay': MusicBeatState.switchState(new FreeplayState());
                        #if MODS_ALLOWED
                        case 'mods': MusicBeatState.switchState(new ModsMenuState());
                        #end
                        case 'awards': MusicBeatState.switchState(new AchievementsMenuState());
                        case 'credits': MusicBeatState.switchState(new CreditsState());
                        case 'options': LoadingState.loadAndSwitchState(new options.OptionsState());
                    }
                });
            }
        });
    }

    // ========================= Menu Navigation =========================
    function changeItem(delta:Int = 0)
    {
        curSelected += delta;
        if (curSelected >= menuItems.length) curSelected = 0;
        if (curSelected < 0) curSelected = menuItems.length - 1;

        menuItems.forEach(function(spr:FlxSprite)
        {
            spr.animation.play('idle');
            spr.updateHitbox();
            if (spr.ID == curSelected)
            {
                spr.animation.play('selected');
                var offsetY:Float = menuItems.length > 4 ? menuItems.length * 8 : 0;
                camFollow.setPosition(spr.getGraphicMidpoint().x, spr.getGraphicMidpoint().y - offsetY);
                spr.centerOffsets();
            }
        });
    }
}