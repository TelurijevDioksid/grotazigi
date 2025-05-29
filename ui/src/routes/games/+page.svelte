<script lang="ts">
    let loading = $state(false);
    let games: {
        winner: string,
        loser: string,
        pointswinner: number,
        pointsloser: number,
    }[] = $state([]);
    let user = $state("");

    $effect(() => {
        getGame();
        const u = sessionStorage.getItem("user");
        if (!u) {
            window.location.href = "/login";
            return;
        }
        user = u;
    });

    const getGame = () => {
        fetch("http://localhost:8080/api/game", {
            credentials: "include",
            method: "GET",
            headers: {
                "Content-Type": "application/json",
            },
        }).then((res) => {
            if (res.status === 401) {
                sessionStorage.removeItem("user");
                window.location.href = "/login";
                return;
            }
            res.json().then((data) => {
                games = data;
                loading = false;
            })
        }).catch(() => {
            loading = false;
        });
    };
</script>

<svelte:head>
    <title>Register</title>
</svelte:head>

<section>
    {#if loading}
        <div class="spinner-border" role="status">
            <span class="visually-hidden">Loading...</span>
        </div>
    {:else}
        <ul>
            {#each games as game}
                <li class={game.winner === user ? "win-color" : "lose-color"}> 
                    <div style="width: 100%; text-align: start;">{game.winner}</div>
                    <div style="width: 100%; text-align: center;">{game.pointswinner} - {game.pointsloser}</div>
                    <div style="width: 100%; text-align: end;">{game.loser}</div>
                </li>
            {/each}
        </ul>
    {/if}
</section>

<style>
    .win-color {
        background-color: #0aa81f;
    }

    .lose-color {
        background-color: var(--color-theme-1);
    }

    li {
        display: flex;
        align-items: center;
        padding: 0.2rem 1rem;
        width: 100%;
        list-style: none;
        border-radius: 5px;
        border: 1px solid var(--color-theme-2-dark);
        font-size: 1.2rem;
        font-weight: 600;
    }

    section {
        width: 100%;
        padding: 5rem;
    }

    ul {
        width: 100%;
        padding: 0;
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 1rem;
    }
</style>

