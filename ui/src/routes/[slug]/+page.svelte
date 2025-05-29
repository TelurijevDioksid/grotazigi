<script lang="ts">
    import type { PageProps } from "./$types";
    import rock_img from "$lib/images/rock.png";
    import paper_img from "$lib/images/paper.png";
    import scissors_img from "$lib/images/scissors.png";

    interface WsRes {
        opponent_name: string | null,
        your_score: number | null,
        opponent_score: number | null,
        game_winner: boolean | null,
        opponent_move: string | null,
    };

    let { data }: PageProps = $props();
    let ws: WebSocket | null = null;
    let opp_name = $state("");
    let your_score = $state(0);
    let opp_score = $state(0);
    let opp_move = $state("");

    let pop_msg = $state("");
    let show_pop_up = $state(false);
    let user_name = $state("");
    let loading = $state(false);
    let can_play = $state(false);
    let your_move: number | null = $state(null);

    $effect(() => {
        loading = true;

        const user = sessionStorage.getItem("user")
        if (!user) {
            window.location.href = "/";
        }
        user_name = user!;

        if (ws === null) {
            ws = new WebSocket(`ws://localhost:8080/ws?room=${data.roomCode}&user=${user_name}`);
            ws.onclose = wsClose;
            ws.onmessage = (e) => wsMessage(e);
            ws.onopen = wsOpen;
            ws.onerror = () => {
                sessionStorage.removeItem("user");
                window.location.href = "/login";
            };
        }
        loading = false;
    });

    const redirectRooms = () => {
        window.location.href = "/";
    };

    const wsClose = () => {};

    const wsMessage = (event: MessageEvent) => {
        const wsres: WsRes = JSON.parse(event.data);

        if (wsres.opponent_name !== null) {
            can_play = true;
            opp_name = wsres.opponent_name;
        }

        if (wsres.opponent_move !== null) {
            opp_move = wsres.opponent_move;
        }

        if (wsres.your_score !== null) {
            your_score = wsres.your_score;
        }

        if (wsres.opponent_score !== null) {
            opp_score = wsres.opponent_score;
        }

        if (wsres.game_winner !== null && wsres.game_winner) {
            setTimeout(() => {
                show_pop_up = true;
                pop_msg = "Pobjedili ste";
            }, 2000);
            return;
        }
        if (wsres.game_winner !== null && !wsres.game_winner) {
            setTimeout(() => {
                show_pop_up = true;
                pop_msg = "Izgubili ste";
            }, 2000);
            return;
        }

        if (wsres.opponent_move !== null) {
            setTimeout(() => {
                your_move = 0;
                opp_move = "";
                can_play = true;
            }, 2000);
        }
    };

    const wsOpen = () => {};

    const playMove = (move: number) => {
        if (can_play === false) return;
        can_play = false;
        your_move = move;
        ws!.send(JSON.stringify({ move: move  }));
    }
</script>

<svelte:head>
    <title>Register</title>
</svelte:head>

<section>
    {#if loading}
        <div class="spinner-border" role="status">
            <span class="visually-hidden">Loading...</span>
        </div>
    {/if}

    <div class="room-code">Kod: {data.roomCode}</div>

    <div class="wrap">
        {#if show_pop_up}
            <div class="popup">
                <p>{pop_msg}</p>
                <button onclick={() => redirectRooms()}>Ok</button>
            </div>
        {/if}
        <div class="title">
            <p>{user_name} ({your_score})</p>
            {#if opp_name === ""}
                <div>
                    <div class="dot dot-1"></div>
                    <div class="dot dot-2"></div>
                    <div class="dot dot-3"></div>
                    <div class="dot dot-4"></div>
                    <p class="inline">({opp_score})</p>
                </div>
            {:else}
                <p>{opp_name} ({opp_score})</p>
            {/if}
        </div>
        <div class="game">
            <div class="you">
                {#if your_move === 0}
                    <img id="moveimgs" style="opacity: 0;" src={rock_img} alt="rock" />
                {/if}
                {#if your_move === 1}
                    <img id="moveimgs" src={rock_img} alt="rock" />
                {/if}
                {#if your_move === 2}
                    <img id="moveimgs" src={paper_img} alt="paper" />
                {/if}
                {#if your_move === 3}
                    <img id="moveimgs" src={scissors_img} alt="scissors" />
                {/if}
            </div>
            <div class="opp">
                {#if opp_move === ""}
                    <img id="moveimgs" style="opacity: 0;" src={rock_img} alt="rock" />
                {/if}
                {#if opp_move === "rock"}
                    <img id="moveimgs" src={rock_img} alt="rock" />
                {/if}
                {#if opp_move === "paper"}
                    <img id="moveimgs" src={paper_img} alt="paper" />
                {/if}
                {#if opp_move === "scissors"}
                    <img id="moveimgs" src={scissors_img} alt="scissors" />
                {/if}
            </div>
        </div>
    </div>

    <div class="controls">
        <button onclick={() => playMove(1)}>
            <img src={rock_img} alt="rock" />
        </button>
        <button onclick={() => playMove(3)}>
            <img src={scissors_img} alt="scissors" />
        </button>
        <button onclick={() => playMove(2)}>
            <img src={paper_img} alt="paper" />
        </button>
    </div>
</section>

<style>
    .room-code {
        font-size: 1.5rem;
        font-weight: 600;
    }

    .dot {
        display: inline-block;
        width: 0.5rem;
        height: 0.5rem;
        background-color: black;
        border-radius: 50%;
        margin-right: 0.2rem;
        animation: jump 3s infinite;
    }

    @keyframes jump {
        0% {transform: translateY(0);}
        5% {transform: translateY(-10px);}
        10% {transform: translateY(0);}
    }

    .dot-1 {
        -webkit-animation-delay: 100ms;
        animation-delay: 100ms;
    }

    .dot-2 {
        -webkit-animation-delay: 200ms;
        animation-delay: 200ms;
    }

    .dot-3 {
        -webkit-animation-delay: 300ms;
        animation-delay: 300ms;
    }

    .dot-4 {
        -webkit-animation-delay: 400ms;
        animation-delay: 400ms;
    }

    .inline {
        display: inline;
    }

    .game {
        display: flex;
        height: max-content;
    }

    .you {
        width: 50%;
    }

    .opp {
        width: 50%;
    }

    img {
        width: 100%;
    }

    .wrap {
        position: relative;
        border: 1px solid black;
        width: 100%;
        display: flex;
        flex-direction: column;
        flex: 1;
    }

    .controls {
        max-width: 600px;
        width: 50%;
        display: flex;
        justify-content: center;
        gap: 2rem;
        margin-top: 1rem;

        button {
            aspect-ratio: 1/1;
            background-color: var(--color-theme-2);
            color: white;
            border: none;
            padding: 0.5rem 1rem;
            border-radius: 10px;
        }
    }

    .title {
        font-size: 1.5rem;
        font-weight: 600;
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 1rem;
    }

    .popup {
        position: absolute;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        display: flex;
        flex-direction: column;
        justify-content: center;
        align-items: center;
        background-color: rgba(0, 0, 0, 0.5);

        button {
            background-color: var(--color-theme-1);
            color: black;
            border: none;
            padding: 0.5rem 1rem;
            border-radius: 10px;
        }
    }

    section {
        padding: 5rem;
        width: 100%;
        display: flex;
        flex-direction: column;
        justify-content: center;
        align-items: center;
    }
</style>

