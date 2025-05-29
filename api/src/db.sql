CREATE TABLE IF NOT EXISTS users (
    id TEXT NOT NULL,
    name TEXT NOT NULL,
    password BYTEA NOT NULL,
    salt BYTEA NOT NULL,
    admin BOOLEAN NOT NULL,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS games (
    id TEXT NOT NULL,
    winner TEXT NOT NULL,
    loser TEXT NOT NULL,
    pointswinner INTEGER NOT NULL,
    pointsloser INTEGER NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (winner) REFERENCES users(id),
    FOREIGN KEY (loser) REFERENCES users(id)
);

INSERT INTO users (id, name, password, salt, admin) VALUES ('a5480d6b-7cf2-4a09-a0fe-d353930c829a', 'admin', '\xfea1f1b4f6e30c66da81e88bd0312a6090af98e57a94a2', '\x55fae74af8d6b9d37b90e83c7e7c87b7', true);

