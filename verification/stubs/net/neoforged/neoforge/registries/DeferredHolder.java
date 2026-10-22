package net.neoforged.neoforge.registries;
import java.util.function.Supplier;
public class DeferredHolder<T, U extends T> implements Supplier<U> {
    public U get() { return null; }
    public String getName() { return ""; }
    public boolean isPresent() { return false; }
    public net.minecraft.resources.ResourceKey<T> getKey() { return null; }
}
