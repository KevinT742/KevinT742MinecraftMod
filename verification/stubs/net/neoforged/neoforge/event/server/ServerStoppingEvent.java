package net.neoforged.neoforge.event.server;
import net.minecraft.server.MinecraftServer;
import net.neoforged.bus.api.Event;
public class ServerStoppingEvent implements Event {
    public MinecraftServer getServer() { return null; }
}
