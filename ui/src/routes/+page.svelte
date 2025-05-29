<script lang="ts">
    let rooms: { name: string, code: string, players: number, passwordSet: boolean }[] = $state([]);
    let pattern = $state("");
    let error = $state("");
    let loading = $state(false);
    let roomName = $state("");
    let roomCode = $state("");

    $effect(() => {
        getRooms();
    });

    let filteredRooms = $derived.by(() => {
        let ret = rooms;
        if (pattern.length > 0) {
            ret = rooms.filter(room => room.name.toLowerCase().includes(pattern.toLowerCase()));
        }
        return ret;
    });

    const joinRoom = (code: string) => {
        window.location.href = `/${code}`
    }

    const getRooms = () => {
        rooms = [];
        loading = true;
        fetch("http://localhost:8080/api/rooms", { credentials: "include" }).then(res => {
            if (res.status === 401) {
                sessionStorage.removeItem("user");
                window.location.href = "/login";
                return;
            }
            res.json().then(data => {
                rooms = data;
                loading = false;
            });
        }).catch(() => {
            rooms = [];
            loading = false;
        });
    };

    const createRoom = () => {
        rooms = [];
        loading = true;
        fetch(`http://localhost:8080/api/rooms`, {
            credentials: "include",
            method: "POST",
            body: JSON.stringify({
                name: roomName,
            })
        }).then(res => {
            if (res.status === 401) {
                sessionStorage.removeItem("user");
                window.location.href = "/login";
                return;
            }
            res.json().then(o => {
                window.location.href = `/${o.code}`
            });
            loading = false;
        }).catch(() => {
            loading = false;
            error = "Nepoznata greška";
        })
    };
</script>

<svelte:head>
    <title>Register</title>
</svelte:head>

<section>
    <div class="input-group mb-3">
        <input bind:value={roomCode} type="text" class="form-control" placeholder="Kod" />
        <span class="input-group-text no-pad" id="basic-addon1">
            <button type="button" onclick={() => joinRoom(roomCode)} class="btn btn-create">Pridruži se</button>
        </span>
    </div>

    <div class="input-group mb-3">
        <span class="input-group-text" id="basic-addon1">
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-search" viewBox="0 0 16 16">
                <path d="M11.742 10.344a6.5 6.5 0 1 0-1.397 1.398h-.001q.044.06.098.115l3.85 3.85a1 1 0 0 0 1.415-1.414l-3.85-3.85a1 1 0 0 0-.115-.1zM12 6.5a5.5 5.5 0 1 1-11 0 5.5 5.5 0 0 1 11 0"/>
            </svg>
        </span>
        <input bind:value={pattern} type="text" class="form-control" placeholder="traži sobu" />
        <span class="input-group-text no-pad" id="basic-addon1">
            <button type="button" onclick={getRooms} class="btn btn-refresh">Osvježi listu</button>
        </span>
    </div>

    <div class="input-group mb-3">
        <input bind:value={roomName} type="text" class="form-control" placeholder="Ime sobe" />
        <span class="input-group-text no-pad" id="basic-addon1">
            <button type="button" onclick={createRoom} class="btn btn-create">Kreiraj sobu</button>
        </span>
    </div>

    <ul>
        {#if loading}
            <div class="spinner-border" role="status">
                <span class="visually-hidden">Loading...</span>
            </div>
        {/if}
        {#if loading === false}
            {#each filteredRooms as room}
                <li>
                    <button class="no-btn" onclick={() => joinRoom(room.code)}>
                        <p>{room.name}</p>
                        <p>{room.players} / 2</p>
                    </button>
                </li>
            {/each}
        {/if}
    </ul>
    {#if error}
        <p class="text-danger">{error}</p>
    {/if}
</section>

<style>
    .no-btn {
        background-color: transparent;
        border: none;
        margin: 0;
        padding: 0.5rem;
        width: 100%;
        height: 100%;
        display: flex;
        justify-content: space-between;
        align-items: center;
    }

    .no-pad {
        padding: 0;
    }

    .text-danger {
        color: red;
        width: 100%;
        text-align: center;
    }

    .btn-create {
        width: 100%;
        border-radius: 0;
        color: white;
        background-color: var(--color-theme-1);
    }

    .btn-create:hover {
        background-color: var(--color-theme-1-dark);
    }

    .btn-refresh {
        width: 100%;
        color: white;
        border-bottom-left-radius: 0;
        border-top-left-radius: 0;
        background-color: var(--color-theme-2);
    }

    .btn-refresh:hover {
        background-color: var(--color-theme-2-dark);
    }

    section {
        padding: 5rem;
        width: 100%;
    }

    ul {
        width: 100%;
        padding: 0;
        display: flex;
        flex-direction: column;
        gap: 1rem;
    }

    li {
        width: 100%;
        list-style: none;
        border-radius: 5px;
        border: 1px solid var(--color-theme-2-dark);
    }

    li * {
        margin: 0;
    }
</style>

