package net.neoforged.neoforge.client.gui;
import net.minecraft.client.Minecraft;
public interface IConfigScreenFactory {
    net.minecraft.client.gui.screens.Screen createScreen(Minecraft minecraft, net.neoforged.fml.ModContainer modContainer);
}
