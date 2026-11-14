import definePlugin from "@utils/types";

import Settings from "./settings";
import runScript from "./script";
import { checkForUpdates } from "./updateChecker";

const BUTTON_ID = "vencord-quest-script-button";

const spacedPluginName = "Quest Spoofer";
const pluginName = spacedPluginName.replaceAll(" ", "");

// ===== PERSONALIZAÇÃO DO BOTÃO (mude aqui) =====
const DEFAULT_LABEL = "Completar Missões";
const RUNNING_LABEL = "A executar...";
const FAILED_LABEL = "Falhou";
const COLOR_A = "#8e2de2"; // cor inicial do degradê
const COLOR_B = "#4a00e0"; // cor final do degradê
const ICON_SVG = `<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"></polygon></svg>`;
// ================================================

function setButtonContent(button: HTMLButtonElement, text: string) {
    button.innerHTML = `${ICON_SVG}<span>${text}</span>`;
}

let observer: MutationObserver | null = null;
let syncScheduled = false;

function isOnQuestsPage() {
    // Current Discord Quest route is /quest-home.
    // /quests is included as a fallback in case Discord changes/reroutes it.
    return (
        location.pathname.includes("/quest-home") ||
        location.pathname.includes("/quests")
    );
}

function styleButton(button: HTMLButtonElement, floating: boolean) {
    button.style.cssText = `
        height: 32px;
        padding: 0 16px;
        border: none;
        border-radius: 8px;
        background: linear-gradient(135deg, ${COLOR_A}, ${COLOR_B});
        color: white;
        font-family: inherit;
        font-size: 14px;
        font-weight: 600;
        display: inline-flex;
        align-items: center;
        gap: 8px;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.35);
        cursor: pointer;
        transition:
            background 0.15s ease,
            opacity 0.15s ease;
        ${floating ? `
            position: fixed;
            top: 70px;
            right: 24px;
            z-index: 9999;
        ` : `
            position: relative;
            margin-left: 8px;
        `}
    `;
}

function createButton() {
    const button = document.createElement("button");

    button.id = BUTTON_ID;
    button.type = "button";
    setButtonContent(button, DEFAULT_LABEL);
    button.setAttribute("aria-label", DEFAULT_LABEL);

    button.addEventListener("mouseenter", () => {
        if (!button.disabled)
            button.style.opacity = "0.85";
    });

    button.addEventListener("mouseleave", () => {
        button.style.opacity = "1";
    });

    button.addEventListener("click", async () => {
        button.disabled = true;
        setButtonContent(button, RUNNING_LABEL);
        button.style.opacity = "0.6";
        button.style.cursor = "not-allowed";

        try {
            await runScript();
        } catch (error) {
            console.error(
                `[${pluginName}] Error while running script:`,
                error
            );

            setButtonContent(button, FAILED_LABEL);

            setTimeout(() => {
                setButtonContent(button, DEFAULT_LABEL);
            }, 2000);
        } finally {
            button.disabled = false;
            button.style.opacity = "1";
            button.style.cursor = "pointer";

            if (button.textContent === RUNNING_LABEL)
                setButtonContent(button, DEFAULT_LABEL);
        }
    });

    return button;
}

function removeButton() {
    document.getElementById(BUTTON_ID)?.remove();
}


function syncButton() {
    if (!isOnQuestsPage()) {
        removeButton();
        return;
    }

    let button = document.getElementById(
        BUTTON_ID
    ) as HTMLButtonElement | null;

    if (!button)
        button = createButton();

    // Discord currently exposes a headingControls container on the Quest page. Put the button there when possible.
    const headingControls =
        document.querySelector<HTMLElement>(
            'div[class*="headingControls"]'
        );

    if (headingControls) {
        if (button.parentElement !== headingControls)
            headingControls.prepend(button);

        styleButton(button, false);
        return;
    }

    // Fallback: If Discord changes the Quest header classes, the plugin still works by displaying a floating button.
    if (button.parentElement !== document.body)
        document.body.appendChild(button);

    styleButton(button, true);
}

function scheduleSync() {
    if (syncScheduled)
        return;

    syncScheduled = true;

    requestAnimationFrame(() => {
        syncScheduled = false;
        syncButton();
    });
}

export default definePlugin({
    name: pluginName,
    description: "Adds a button to the Quests page that allows you to automatically complete active quests." +
        "You must activate the quests in order for them to be completed." +
        "The button should be located next to the sorting and filtering buttons.",
    authors: [{ name: "Kanji", id: 1102529638443528202n }],
    settings: Settings,

    start() {
        console.log(`[${pluginName}] Started`);

        if (Settings.store.checkForUpdates) {
            checkForUpdates(spacedPluginName);
        }

        syncButton();

        observer = new MutationObserver(scheduleSync);

        observer.observe(document.body, {
            childList: true,
            subtree: true
        });
    },

    stop() {
        console.log(`[${pluginName}] Stopped`);

        observer?.disconnect();
        observer = null;

        removeButton();
    }
});
