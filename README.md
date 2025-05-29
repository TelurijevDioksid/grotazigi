# Grotazigi
Jednostavna aplikacija za igranje igre kamen, škare i papir u stvarnom vremenu.

## Pokretanje projekta
Klonirajte repozitoriji naredbom:
```bash
git clone git@github.com:TelurijevDioksid/grotazigi.git
cd grotazigi
```

### baza podataka:
Potrebno je imati alate _docker_ i _docker-compose_. Pokretanje baze podataka pomoću _docker-compose_ naredbe:
```bash
docker-compose up
```

### Api-a:
Potrebno je imati instaliran _Zig_ izvršnu datoteku. Potrebno je navigirati u api direktoriji i pokrenuti naredbu:
```bash
cd api
zig build run
```

### web aplikacija:
Potrebno je imati instaliran _Node.js JavaScript runtime_ i _npm_. Navigirati u ui direktorij i pokrenuti naredbe:
```bash
cd ui
npm install
npm run dev
```

## API Endpoints
| Endpoint | Method | Description |
|---|---|---|
| /api/register | POST | Registracija novog korisnika |
| /api/login | POST | Prijava postojećeg korisnika |
| /api/logout | GET | Odjava korisnika |
| /api/profile | GET | Dohvaćanje profila prijavljenog korisnika |
| /api/rooms | GET | Dohvaćanje svih soba |
| /api/rooms | POST | Kreiranje nove sobe |
| /api/game | GET | Dohvaćanje svih igara |
| /api/game/:id | GET | Dohvaćanje igre po ID-u |
| /api/game | POST | Kreiranje nove igre |
| /api/game/:id | PUT | Ažuriranje igre po ID-u |
| /api/game/:id | DELETE | Brisanje igre po ID-u |
| /ws | GET | WebSocket endpoint za igru |

## UI rute
| Ruta | Opis |
|---|---|
| / | Lista dostupnih soba za igru |
| /login | Stranica za prijavu |
| /register | Stranica za registraciju |
| /games | Lista odigranih igara |
| /:slug | Stranica igre (kamen, škare, papir) |