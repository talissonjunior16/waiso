# Waiso for Claude

Connects Claude to your Waiso workspace. Ask it to write a script, build a flow, schedule a run, publish
an endpoint or build a robot that reads a website, and it does the work in your projects while you watch
it happen in the open app.

## Install

```
/plugin marketplace add talissonjunior16/waiso
/plugin install waiso@waiso
```

The first time Claude uses Waiso, your browser opens the Waiso sign-in. Pick the projects Claude may reach
and whether it may change them, then press Allow. You can end the connection at any time in
Settings → Access tokens.

## Your own server

If you run Waiso yourself, change the address in `.mcp.json` to your own, for example
`https://waiso.example.com/mcp`.

## What it can do

Projects, scripts in nine languages, flows, schedules, endpoints, variables, connections, robots, runs and
their logs, Git and alerts. Everything is limited to what you allowed and to what your own account may do.
