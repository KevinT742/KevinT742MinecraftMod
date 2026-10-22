package net.neoforged.fml.common;
import net.neoforged.api.distmarker.Dist;
import java.lang.annotation.*;
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
public @interface Mod {
    String value();
    Dist[] dist() default { Dist.CLIENT, Dist.DEDICATED_SERVER };
}
