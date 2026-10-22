$ErrorActionPreference = 'Stop'

# ============================================================================
# 生成 NeoForge API 的最小桩件（不进产物，只用于离线编译校验）
# ============================================================================
# ⚠️ 铁律：桩件必须与**真实 NeoForge 源码逐个签名对齐**，不能照着调用方的期望手写。
#
#    踩过的坑（2026-10-22）：早期这里把 DeferredRegister 的注册方法写成
#    registerSimpleBlock(String, Function<Properties,Properties>) 和
#    registerSimpleItem(String, Consumer<Item.Properties>)，还凭空捏造了
#    net.neoforged.neoforge.event.entity.PlayerEvent.PlayerTick。
#    真实 API 里这些都不存在 —— properties 重载的参数类型是 UnaryOperator
#    （它是 Function 的**子接口**，反过来不成立），玩家 tick 事件是
#    net.neoforged.neoforge.event.tick.PlayerTickEvent，PlayerEvent 在
#    net.neoforged.neoforge.event.entity.**player** 包下，且 getEntity() 返回 Player。
#
#    结果：离线验证一直是绿的，真编译（对真实 NeoForge）才炸。
#
#    改本文件前，先去 neoforged/NeoForge 对应分支核对真实签名：
#        https://github.com/neoforged/NeoForge  →  src/main/java/net/neoforged/neoforge/
#    本工程当前对齐的分支：**26.2.x**（对应 NeoForge 26.2.0.93）。
# ============================================================================

$root = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'stubs'
if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }

$stubs = @{
'net/neoforged/api/distmarker/Dist.java' = @'
package net.neoforged.api.distmarker;
public enum Dist { CLIENT, DEDICATED_SERVER }
'@
'net/neoforged/fml/common/Mod.java' = @'
package net.neoforged.fml.common;
import net.neoforged.api.distmarker.Dist;
import java.lang.annotation.*;
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
public @interface Mod {
    String value();
    Dist[] dist() default { Dist.CLIENT, Dist.DEDICATED_SERVER };
}
'@
'net/neoforged/fml/common/EventBusSubscriber.java' = @'
package net.neoforged.fml.common;
import net.neoforged.api.distmarker.Dist;
import java.lang.annotation.*;
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
public @interface EventBusSubscriber {
    String modid() default "";
    Dist[] value() default { Dist.CLIENT, Dist.DEDICATED_SERVER };
    boolean bus() default true;
}
'@
'net/neoforged/fml/ModContainer.java' = @'
package net.neoforged.fml;
import net.neoforged.fml.config.ModConfig;
import net.neoforged.neoforge.common.ModConfigSpec;
public interface ModContainer {
    <T> void registerExtensionPoint(Class<T> type, T extension);
    void registerConfig(ModConfig.Type type, ModConfigSpec spec);
}
'@
'net/neoforged/fml/config/ModConfig.java' = @'
package net.neoforged.fml.config;
public class ModConfig {
    public enum Type { COMMON, CLIENT, SERVER, STARTUP }
}
'@
'net/neoforged/fml/event/lifecycle/FMLCommonSetupEvent.java' = @'
package net.neoforged.fml.event.lifecycle;
import net.neoforged.bus.api.Event;
public class FMLCommonSetupEvent implements Event {
}
'@
'net/neoforged/fml/event/lifecycle/FMLClientSetupEvent.java' = @'
package net.neoforged.fml.event.lifecycle;
import net.neoforged.bus.api.Event;
public class FMLClientSetupEvent implements Event {
}
'@
'net/neoforged/bus/api/Event.java' = @'
package net.neoforged.bus.api;
public interface Event {
}
'@
'net/neoforged/bus/api/SubscribeEvent.java' = @'
package net.neoforged.bus.api;
import java.lang.annotation.*;
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.METHOD)
public @interface SubscribeEvent {
    int priority() default 0;
    boolean receiveCancelled() default false;
}
'@
'net/neoforged/bus/api/IEventBus.java' = @'
package net.neoforged.bus.api;
public interface IEventBus {
    <T extends Event> void addListener(java.util.function.Consumer<T> listener);
    <T extends Event> void addListener(java.util.function.Consumer<T> listener, Class<T> type);
    void register(Object target);
}
'@
'net/neoforged/neoforge/common/NeoForge.java' = @'
package net.neoforged.neoforge.common;
import net.neoforged.bus.api.IEventBus;
public final class NeoForge {
    public static final IEventBus EVENT_BUS = null;
    private NeoForge() {}
}
'@
'net/neoforged/neoforge/common/ModConfigSpec.java' = @'
package net.neoforged.neoforge.common;
public class ModConfigSpec {
    public static class Builder {
        public Builder comment(String comment) { return this; }
        public Builder push(String path) { return this; }
        public Builder pop() { return this; }
        public BooleanValue define(String path, boolean value) { return new BooleanValue(); }
        public IntValue define(String path, int value) { return new IntValue(); }
        public IntValue defineInRange(String path, int value, int min, int max) { return new IntValue(); }
        public DoubleValue define(String path, double value) { return new DoubleValue(); }
        public DoubleValue defineInRange(String path, double value, double min, double max) { return new DoubleValue(); }
        public <T> ConfigValue<T> define(String path, T value) { return new ConfigValue<>(); }
        public ModConfigSpec build() { return new ModConfigSpec(); }
    }
    public static class BooleanValue {
        public boolean getAsBoolean() { return false; }
        public boolean get() { return false; }
    }
    public static class IntValue {
        public int getAsInt() { return 0; }
        public int get() { return 0; }
    }
    public static class DoubleValue {
        public double getAsDouble() { return 0; }
        public double get() { return 0; }
    }
    public static class ConfigValue<T> {
        public T get() { return null; }
    }
}
'@
'net/neoforged/neoforge/registries/DeferredHolder.java' = @'
package net.neoforged.neoforge.registries;
import java.util.function.Supplier;
public class DeferredHolder<T, U extends T> implements Supplier<U> {
    public U get() { return null; }
    public String getName() { return ""; }
    public boolean isPresent() { return false; }
    public net.minecraft.resources.ResourceKey<T> getKey() { return null; }
}
'@
'net/neoforged/neoforge/registries/DeferredBlock.java' = @'
package net.neoforged.neoforge.registries;
import net.minecraft.world.level.block.Block;
public class DeferredBlock<T extends Block> extends DeferredHolder<Block, T> {
}
'@
'net/neoforged/neoforge/registries/DeferredItem.java' = @'
package net.neoforged.neoforge.registries;
import net.minecraft.world.item.Item;
public class DeferredItem<T extends Item> extends DeferredHolder<Item, T> {
}
'@
'net/neoforged/neoforge/registries/DeferredRegister.java' = @'
// 桩件：签名对照 NeoForge 26.2.x 的 DeferredRegister.java，勿凭印象修改。
package net.neoforged.neoforge.registries;
import java.util.function.Function;
import java.util.function.Supplier;
import java.util.function.UnaryOperator;
import net.minecraft.core.Holder;
import net.minecraft.core.Registry;
import net.minecraft.resources.ResourceKey;
import net.minecraft.world.item.BlockItem;
import net.minecraft.world.item.Item;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockBehaviour;
public class DeferredRegister<T> {
    public static <T> DeferredRegister<T> create(ResourceKey<? extends Registry<T>> key, String modid) { return null; }
    public static Blocks createBlocks(String modid) { return null; }
    public static Items createItems(String modid) { return null; }
    public <I extends T> DeferredHolder<T, I> register(String name, Supplier<? extends I> supplier) { return null; }
    public void register(net.neoforged.bus.api.IEventBus bus) {}

    public static class Blocks {
        public void register(net.neoforged.bus.api.IEventBus bus) {}
        public <B extends Block> DeferredBlock<B> register(String name, Supplier<? extends B> sup) { return null; }
        public <B extends Block> DeferredBlock<B> registerBlock(String name, Function<BlockBehaviour.Properties, ? extends B> func) { return null; }
        public DeferredBlock<Block> registerSimpleBlock(String name, Supplier<BlockBehaviour.Properties> properties) { return null; }
        public DeferredBlock<Block> registerSimpleBlock(String name, UnaryOperator<BlockBehaviour.Properties> properties) { return null; }
        public DeferredBlock<Block> registerSimpleBlock(String name) { return null; }
    }
    public static class Items {
        public void register(net.neoforged.bus.api.IEventBus bus) {}
        public <I extends Item> DeferredItem<I> register(String name, Supplier<? extends I> sup) { return null; }
        public <I extends Item> DeferredItem<I> registerItem(String name, Function<Item.Properties, ? extends I> func) { return null; }
        public DeferredItem<BlockItem> registerSimpleBlockItem(String name, Supplier<? extends Block> block) { return null; }
        public DeferredItem<BlockItem> registerSimpleBlockItem(Holder<Block> block) { return null; }
        public DeferredItem<Item> registerSimpleItem(String name, Supplier<Item.Properties> properties) { return null; }
        public DeferredItem<Item> registerSimpleItem(String name, UnaryOperator<Item.Properties> properties) { return null; }
        public DeferredItem<Item> registerSimpleItem(String name) { return null; }
    }
}
'@
'net/neoforged/neoforge/event/BuildCreativeModeTabContentsEvent.java' = @'
package net.neoforged.neoforge.event;
import java.util.function.Supplier;
import net.minecraft.resources.ResourceKey;
import net.minecraft.world.item.CreativeModeTab;
import net.minecraft.world.item.ItemStack;
import net.neoforged.bus.api.Event;
public class BuildCreativeModeTabContentsEvent implements Event {
    public ResourceKey<CreativeModeTab> getTabKey() { return null; }
    public void accept(net.minecraft.world.level.ItemLike item) {}
    public void accept(java.util.function.Supplier<? extends net.minecraft.world.level.ItemLike> item) {}
    public void accept(net.minecraft.world.item.ItemStack stack) {}
}
'@
'net/neoforged/neoforge/event/server/ServerStartingEvent.java' = @'
package net.neoforged.neoforge.event.server;
import net.minecraft.server.MinecraftServer;
import net.neoforged.bus.api.Event;
public class ServerStartingEvent implements Event {
    public MinecraftServer getServer() { return null; }
}
'@
'net/neoforged/neoforge/event/server/ServerStoppingEvent.java' = @'
package net.neoforged.neoforge.event.server;
import net.minecraft.server.MinecraftServer;
import net.neoforged.bus.api.Event;
public class ServerStoppingEvent implements Event {
    public MinecraftServer getServer() { return null; }
}
'@
'net/neoforged/neoforge/event/entity/player/PlayerEvent.java' = @'
// 桩件：签名对照 NeoForge 26.2.x 的 event/entity/player/PlayerEvent.java，勿凭印象修改。
package net.neoforged.neoforge.event.entity.player;
import net.minecraft.world.entity.player.Player;
import net.neoforged.bus.api.Event;
public abstract class PlayerEvent implements Event {
    protected PlayerEvent(Player player) {
    }
    public Player getEntity() { return null; }
    public static class PlayerLoggedInEvent extends PlayerEvent {
        public PlayerLoggedInEvent(Player player) { super(player); }
    }
    public static class PlayerLoggedOutEvent extends PlayerEvent {
        public PlayerLoggedOutEvent(Player player) { super(player); }
    }
}
'@
'net/neoforged/neoforge/event/tick/PlayerTickEvent.java' = @'
// 桩件：签名对照 NeoForge 26.2.x 的 event/tick/PlayerTickEvent.java，勿凭印象修改。
package net.neoforged.neoforge.event.tick;
import net.minecraft.world.entity.player.Player;
import net.neoforged.neoforge.event.entity.player.PlayerEvent;
public abstract class PlayerTickEvent extends PlayerEvent {
    protected PlayerTickEvent(Player player) { super(player); }
    public static class Pre extends PlayerTickEvent {
        public Pre(Player player) { super(player); }
    }
    public static class Post extends PlayerTickEvent {
        public Post(Player player) { super(player); }
    }
}
'@
'net/neoforged/neoforge/client/gui/IConfigScreenFactory.java' = @'
package net.neoforged.neoforge.client.gui;
import net.minecraft.client.Minecraft;
public interface IConfigScreenFactory {
    net.minecraft.client.gui.screens.Screen createScreen(Minecraft minecraft, net.neoforged.fml.ModContainer modContainer);
}
'@
'net/neoforged/neoforge/client/gui/ConfigurationScreen.java' = @'
package net.neoforged.neoforge.client.gui;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.screens.Screen;
import net.neoforged.fml.ModContainer;
public class ConfigurationScreen extends Screen {
    public ConfigurationScreen(Minecraft minecraft, ModContainer container) { super(null); }
}
'@
}

foreach ($path in $stubs.Keys) {
    $full = Join-Path $root ($path -replace '/', '\')
    $dir = Split-Path -Parent $full
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -LiteralPath $full -Value $stubs[$path] -Encoding utf8
}
Write-Host "generated $($stubs.Count) stub files in $root"





