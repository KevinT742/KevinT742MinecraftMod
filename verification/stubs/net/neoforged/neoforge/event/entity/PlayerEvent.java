package net.neoforged.neoforge.event.entity;
import net.minecraft.server.level.ServerPlayer;
import net.neoforged.bus.api.Event;
public class PlayerEvent implements Event {
    public ServerPlayer getEntity() { return null; }
    public static class PlayerTick extends PlayerEvent {
    }
    public static class PlayerLoggedIn extends PlayerEvent {
    }
}
