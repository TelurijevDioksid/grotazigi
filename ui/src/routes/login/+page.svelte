<script lang="ts">
    let name = $state("");
    let password = $state("");
    let error = $state("");

    const inputFocus = () => {
        error = "";
    }

    $effect(() => {
        if (sessionStorage.getItem("user")) {
            window.location.href = "/";
        }
    });

    const login = () => {
        fetch("http://localhost:8080/api/login", {
            credentials: "include",
            method: "POST",
            headers: {
                "Content-Type": "application/json",
            },
            body: JSON.stringify({
                name: name,
                password: password,
            }),
        }).then((res) => {
            if (res.status === 200) {
                window.location.href = "/";
            }
            if (res.status === 401) {
                sessionStorage.removeItem("user");
                error = "Pogresno ime ili lozinka";
            }
        }).catch(() => {
            error = "Nepozanta greška. Pokušajte kasnije.";
        });
    };
</script>

<svelte:head>
    <title>Home</title>
    <meta name="description" content="Grotazigi App" />
</svelte:head>

<section>
    <div>
        <h1>Prijava</h1>
        <input onfocusin={inputFocus} bind:value={name} type="text" class="form-control" placeholder="Ime" />
        <input onfocusin={inputFocus} bind:value={password} type="password" class="form-control" placeholder="Lozinka" />
        <button onclick={login} class="btn btn-log">Prijavi se</button>
        <a href="/register" class="btn btn-reg">Registriraj se</a>
        {#if error}
            <p class="text-danger">{error}</p>
        {/if}
    </div>
</section>

<style>
    .text-danger {
        color: red;
        width: 100%;
        text-align: center;
    }

    .btn-log {
        width: 100%;
        color: white;
        background-color: var(--color-theme-2);
    }

    .btn-log:hover {
        background-color: var(--color-theme-2-dark);
    }

    .btn-reg {
        width: 100%;
        color: white;
        background-color: var(--color-theme-1);
    }

    .btn-reg:hover {
        background-color: var(--color-theme-1-dark);
    }

    section {
        width: 100%;
        display: flex;
        flex-direction: column;
        justify-content: center;
        align-items: center;
        flex: 0.6;
    }

    div {
        max-width: 600px;
        display: flex;
        flex-direction: column;
        justify-content: center;
        align-items: center;
        gap: 1rem;
    }
</style>

