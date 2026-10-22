package net.neoforged.bus.api;
public interface IEventBus {
    <T extends Event> void addListener(java.util.function.Consumer<T> listener);
    <T extends Event> void addListener(java.util.function.Consumer<T> listener, Class<T> type);
    void register(Object target);
}
