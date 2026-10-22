package net.neoforged.fml.common;
import net.neoforged.api.distmarker.Dist;
import java.lang.annotation.*;
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
public @interface EventBusSubscriber {
    String modid() default "";
    Dist[] value() default { Dist.CLIENT, Dist.DEDICATED_SERVER };
    boolean bus() default true;
}
