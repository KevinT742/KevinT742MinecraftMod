package net.neoforged.neoforge.registries;
import java.util.function.Consumer;
import java.util.function.Function;
import java.util.function.Supplier;
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
    public DeferredHolder<T, T> register(String name, Supplier<? extends T> supplier) { return null; }
    public void register(net.neoforged.bus.api.IEventBus bus) {}

    public static class Blocks {
        public void register(net.neoforged.bus.api.IEventBus bus) {}
        public DeferredBlock<Block> registerSimpleBlock(String name, Function<BlockBehaviour.Properties, BlockBehaviour.Properties> properties) { return null; }
        public DeferredBlock<Block> registerSimpleBlock(String name, Block block) { return null; }
    }
    public static class Items {
        public void register(net.neoforged.bus.api.IEventBus bus) {}
        public DeferredItem<BlockItem> registerSimpleBlockItem(String name, DeferredHolder<Block, ? extends Block> block) { return null; }
        public DeferredItem<Item> registerSimpleItem(String name, Consumer<Item.Properties> properties) { return null; }
    }
}
