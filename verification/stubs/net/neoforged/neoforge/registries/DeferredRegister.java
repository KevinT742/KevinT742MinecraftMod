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
