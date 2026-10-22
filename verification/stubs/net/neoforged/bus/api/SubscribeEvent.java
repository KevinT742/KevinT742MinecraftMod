package net.neoforged.bus.api;
import java.lang.annotation.*;
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.METHOD)
public @interface SubscribeEvent {
    int priority() default 0;
    boolean receiveCancelled() default false;
}
