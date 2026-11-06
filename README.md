# rrx-poc-ui

POC page served by nginx. The browser calls `/api/...` on this origin; nginx forwards `/api/` to the backend.

Start the API so it listens on port 8000, then run `docker compose up --build`. Open http://localhost:3000.

`npm run dev` proxies `/api` to http://localhost:8000 for frontend-only development.

Release from a clean main that matches origin/main: `.\release.ps1 -Bump patch -RemoteImage "<dockerhub-user>/poc-ui"`.
