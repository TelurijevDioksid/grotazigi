<script lang="ts">
    import { page } from "$app/state";

    let user = $state("");

    $effect(() => {
        if (sessionStorage.getItem("user")) {
            user = sessionStorage.getItem("user")!;
            return;
        }
        fetch("http://localhost:8080/api/profile", { credentials: "include" }).then((res) => {
            if (res.status === 200) {
                res.json().then((profile: { name: string }) => {
                    user = profile.name;
                    sessionStorage.setItem("user", profile.name);
                })
            }
        }).catch(() => {});
    });

    const logout = () => {
        sessionStorage.removeItem("user");
        fetch("http://localhost:8080/api/logout", { credentials: "include" }).then((res) => {
            user = "";
            window.location.href = "/login";
        });
    }
</script>

<header>
    <nav>
        <svg viewBox="0 0 2 3" aria-hidden="true">
            <path d="M0,0 L1,2 C1.5,3 1.5,3 2,3 L2,0 Z" />
        </svg>
        <ul>
            {#if user === ""}
                <li aria-current={page.url.pathname === "/login" ? "page" : undefined}>
                    <a href="/login">Prijavi se</a>
                </li>
                <li aria-current={page.url.pathname === "/register" ? "page" : undefined}>
                    <a href="/register">Registriraj se</a>
                </li>
            {:else}
                <li aria-current={page.url.pathname === "/" ? "page" : undefined}>
                    <a href="/">Igre</a>
                </li>
                <li aria-current={page.url.pathname.startsWith("/games") ? "page" : undefined}>
                    <a href="/games">Odigrano</a>
                </li>
                <li>
                    <button onclick={() => logout()}>Odjavi se</button>
                </li>
                <li>
                    <div class="vertical-line"></div>
                </li>
                <li>
                    <p>{user}</p>
                </li>
            {/if}
        </ul>
        <svg viewBox="0 0 2 3" aria-hidden="true">
            <path d="M0,0 L0,3 C0.5,3 0.5,3 1,2 L2,0 Z" />
        </svg>
    </nav>
</header>

<style>
    .vertical-line {
        width: 2px;
        height: 100%;
        background-color: var(--color-theme-1);
    }

    header {
        display: flex;
        justify-content: center;
    }

    nav {
        display: flex;
        justify-content: center;
        --background: rgba(255, 255, 255, 0.7);
    }

    svg {
        width: 2em;
        height: 3em;
        display: block;
    }

    path {
        fill: var(--background);
    }

    ul {
        position: relative;
        padding: 0;
        margin: 0;
        height: 3em;
        display: flex;
        justify-content: center;
        align-items: center;
        list-style: none;
        background: var(--background);
        background-size: contain;
    }

    li {
        position: relative;
        height: 100%;
    }

    li[aria-current='page']::before {
        --size: 6px;
        content: '';
        width: 0;
        height: 0;
        position: absolute;
        top: 0;
        left: calc(50% - var(--size));
        border: var(--size) solid transparent;
        border-top: var(--size) solid var(--color-theme-1);
    }

    button {
        outline: none;
        border: none;
        background: transparent;
        color: var(--color-text);
        font-weight: 700;
        font-size: 0.8rem;
        letter-spacing: 0.1em;
        text-decoration: none;
        transition: color 0.2s linear;
    }

    nav a, p, button {
        display: flex;
        height: 100%;
        align-items: center;
        padding: 0 0.5rem;
        color: var(--color-text);
        font-weight: 700;
        font-size: 0.8rem;
        letter-spacing: 0.1em;
        text-decoration: none;
        transition: color 0.2s linear;
    }

    a:hover, button:hover {
        color: var(--color-theme-1);
    }
</style>

