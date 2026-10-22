package net.neoforged.fml;
import net.neoforged.fml.config.ModConfig;
import net.neoforged.neoforge.common.ModConfigSpec;
public interface ModContainer {
    <T> void registerExtensionPoint(Class<T> type, T extension);
    void registerConfig(ModConfig.Type type, ModConfigSpec spec);
}
