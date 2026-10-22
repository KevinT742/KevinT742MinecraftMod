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
