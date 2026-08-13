# koha-plugin-kajeet

Koha plugin that checks Kajeet hotspot devices in and out of Kajeet's Media Center

## What it does

When an item of a configured item type is checked out in Koha, the plugin calls
Kajeet's API to check out the device. On check in, the device is checked back in
with Kajeet, which suspends the device. 

## Requirements
- A Kajeet API key for your organization

## Setup

1. Install the plugin and open its configuration page.
2. Enter your Kajeet API key. It is stored encrypted and never redisplayed.
3. Select the item types used for Kajeet hotspots.
4. Store IMEI numbers in Koha's stocknumber/inventory field
