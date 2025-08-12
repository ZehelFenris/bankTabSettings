**What it does**
* Adds a Settings page under Blizzard’s Interface Options (Settings UI).
  * Six accordions: Character Tab 1–6 (all closed by default; only one can be open).
  * Each tab block lets you set:
    * Tab name
    * Icon (currently only supports icon ID need to make icon picker work)
    * Expansion filter: Any / Current Only / Legacy Only
    * Categories (checkboxes): Equipment, Consumables, Profession Goods, Reagents, Junk, Ignore this tab for cleanup
* Saves to a single account‑wide profile
* When you open your bank, it applies settings to your purchased bank tabs.
* Optional debug logging (off by default) with minimal noise; only errors and one summary line are printed.
<br />

**How to setup the bank tabs**  <br />
Open: Game Menu → Options → AddOns → bankTabSettings(or type /tabsettings).
<br />

**Slash commands** <br />
/tabsettings — open the settings panel. <br />
/tabsettings debug — toggle debug logging. <br />
/tabsettings debug on / /tabsettings debug off — explicit enable/disable. <br />
