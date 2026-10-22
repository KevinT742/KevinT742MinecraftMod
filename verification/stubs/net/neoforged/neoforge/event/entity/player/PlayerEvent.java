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
