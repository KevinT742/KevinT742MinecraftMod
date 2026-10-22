$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$res = Join-Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) 'base\src\main\resources'

function WriteJson($relativePath, $obj) {
    $full = Join-Path $res ($relativePath -replace '/', '\')
    $dir = Split-Path -Parent $full
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $json = $obj | ConvertTo-Json -Depth 12
    Set-Content -LiteralPath $full -Value $json -Encoding utf8
}

# ---------------------------------------------------------------------
# blocks: models, blockstates and items
# ---------------------------------------------------------------------
$blocks = @(
    @{ name = 'andesite_brick';  texture = 'minecraft:block/polished_andesite' },
    @{ name = 'deepslate_brick'; texture = 'minecraft:block/polished_deepslate' },
    @{ name = 'packed_earth';    texture = 'minecraft:block/dirt' },
    @{ name = 'gravel_path';     texture = 'minecraft:block/gravel' },
    @{ name = 'cobble_path';     texture = 'minecraft:block/cobblestone' },
    @{ name = 'arcane_brick';    texture = 'minecraft:block/purpur_block' },
    @{ name = 'crystal_block';   texture = 'minecraft:block/amethyst_block' }
)

foreach ($block in $blocks) {
    WriteJson "assets/genesis/blockstates/$($block.name).json" @{
        variants = @{ '' = @{ model = "genesis:block/$($block.name)" } }
    }
    WriteJson "assets/genesis/models/block/$($block.name).json" @{
        parent   = 'minecraft:block/cube_all'
        textures = @{ all = $block.texture }
    }
    WriteJson "assets/genesis/models/item/$($block.name).json" @{
        parent = "genesis:block/$($block.name)"
    }
}

# ---------------------------------------------------------------------
# items: the models of the items that are not blocks
# ---------------------------------------------------------------------
$items = @(
    @{ name = 'crystal_shard'; texture = 'minecraft:item/amethyst_shard' },
    @{ name = 'arcane_dust';   texture = 'minecraft:item/glowstone_dust' },
    @{ name = 'heart_core';    texture = 'minecraft:item/heart_of_the_sea' },
    @{ name = 'spirit_vial';   texture = 'minecraft:item/glass_bottle' },
    @{ name = 'rune_tablet';   texture = 'minecraft:item/book' }
)

foreach ($item in $items) {
    WriteJson "assets/genesis/models/item/$($item.name).json" @{
        parent   = 'minecraft:item/generated'
        textures = @{ layer0 = $item.texture }
    }
}

# ---------------------------------------------------------------------
# language
# ---------------------------------------------------------------------
$lang = [ordered]@{
    'itemGroup.genesis'                     = 'Genesis'
    'block.genesis.andesite_brick'          = 'Andesite Brick'
    'block.genesis.deepslate_brick'         = 'Deepslate Brick'
    'block.genesis.packed_earth'            = 'Packed Earth'
    'block.genesis.gravel_path'             = 'Gravel Path'
    'block.genesis.cobble_path'             = 'Cobblestone Path'
    'block.genesis.arcane_brick'            = 'Arcane Brick'
    'block.genesis.crystal_block'           = 'Crystal Block'
    'item.genesis.crystal_shard'            = 'Crystal Shard'
    'item.genesis.arcane_dust'              = 'Arcane Dust'
    'item.genesis.heart_core'               = 'Heart Core'
    'item.genesis.spirit_vial'              = 'Spirit Vial'
    'item.genesis.rune_tablet'              = 'Rune Tablet'
    'dimension.genesis.terran'              = 'Terran'
    'dimension.genesis.ember'               = 'Ember'
}
WriteJson 'assets/genesis/lang/en_us.json' $lang

# ---------------------------------------------------------------------
# dimension types
# ---------------------------------------------------------------------
$baseType = [ordered]@{
    ambient_light                 = 0.0
    attributes                     = [ordered]@{
        'minecraft:audio/ambient_sounds' = [ordered]@{
            mood = [ordered]@{ block_search_extent = 8; offset = 2.0; sound = 'minecraft:ambient.cave'; tick_delay = 6000 }
        }
        'minecraft:audio/background_music' = [ordered]@{
            creative = [ordered]@{ max_delay = 24000; min_delay = 12000; sound = 'minecraft:music.creative' }
            default  = [ordered]@{ max_delay = 24000; min_delay = 12000; sound = 'minecraft:music.game' }
        }
        'minecraft:gameplay/bed_rule' = [ordered]@{
            can_set_spawn = 'always'; can_sleep = 'when_dark'; error_message = [ordered]@{ translate = 'block.minecraft.bed.no_sleep' }
        }
        'minecraft:gameplay/nether_portal_spawns_piglin' = $true
        'minecraft:gameplay/respawn_anchor_works'        = $false
        'minecraft:visual/ambient_light_color'            = '#0a0a0a'
        'minecraft:visual/cloud_color'                    = '#ccffffff'
        'minecraft:visual/cloud_height'                   = 192.33
        'minecraft:visual/fog_color'                      = '#c0d8ff'
        'minecraft:visual/sky_color'                      = '#78a7ff'
    }
    coordinate_scale               = 1.0
    default_clock                 = 'minecraft:overworld'
    has_ceiling                   = $false
    has_ender_dragon_fight        = $false
    has_skylight                  = $true
    height                        = 384
    infiniburn                    = '#minecraft:infiniburn_overworld'
    logical_height                = 384
    min_y                         = -64
    monster_spawn_block_light_limit = 0
    monster_spawn_light_level     = [ordered]@{ type = 'minecraft:uniform'; max_inclusive = 7; min_inclusive = 0 }
    timelines                     = '#minecraft:in_overworld'
}

WriteJson 'data/genesis/dimension_type/terran.json' $baseType

$emberType = [ordered]@{}
foreach ($key in $baseType.Keys) { $emberType[$key] = $baseType[$key] }
$emberType['attributes'] = [ordered]@{}
foreach ($key in $baseType.attributes.Keys) { $emberType.attributes[$key] = $baseType.attributes[$key] }
$emberType.attributes['minecraft:visual/fog_color'] = '#e8d5b0'
$emberType.attributes['minecraft:visual/sky_color'] = '#8fb6e8'
$emberType.attributes['minecraft:visual/cloud_color'] = '#ffffffe6'
WriteJson 'data/genesis/dimension_type/ember.json' $emberType

# ---------------------------------------------------------------------
# dimensions
# ---------------------------------------------------------------------
foreach ($planet in @('terran', 'ember')) {
    WriteJson "data/genesis/dimension/$planet.json" ([ordered]@{
        type      = "genesis:$planet"
        generator = [ordered]@{
            type         = 'genesis:genesis_chunk_generator'
            biome_source = [ordered]@{ type = 'genesis:genesis_biome_source'; planet = "genesis:$planet" }
            planet       = "genesis:$planet"
        }
    })
}

Write-Host "resources written to $res"
Get-ChildItem -LiteralPath $res -Recurse -File | ForEach-Object { $_.FullName.Substring($res.Length + 1) }

