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
