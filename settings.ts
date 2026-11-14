import { definePluginSettings } from "@api/Settings";
import { OptionType } from "@utils/types";

export default definePluginSettings({
    checkForUpdates: {
        type: OptionType.BOOLEAN,
        description: "Check for updates on start (not implemented in this local copy)",
        default: false
    },
    blockMultipleInstances: {
        type: OptionType.BOOLEAN,
        description: "Block running the spoofer more than once at the same time",
        default: true
    },
    showMainNotifications: {
        type: OptionType.BOOLEAN,
        description: "Show main notifications",
        default: true
    },
    showStartNotifications: {
        type: OptionType.BOOLEAN,
        description: "Show a notification when a quest starts",
        default: true
    },
    showFinishNotifications: {
        type: OptionType.BOOLEAN,
        description: "Show a notification when a quest finishes",
        default: true
    },
    showErrorNotifications: {
        type: OptionType.BOOLEAN,
        description: "Show error notifications",
        default: true
    }
});
