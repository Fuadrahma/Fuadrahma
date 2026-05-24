"""
FastAPI-based real-time trading dashboard.
Serves a beautiful single-page app with live portfolio metrics.
"""
from __future__ import annotations
import json
import logging
import math
from typing import Optional, Any

from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware

logger = logging.getLogger(__name__)

_bot_instance = None


def _sanitize(obj: Any) -> Any:
    """Recursively replace non-JSON-safe values (inf, nan, numpy types)."""
    import numpy as np
    if isinstance(obj, (np.integer,)):
        return int(obj)
    if isinstance(obj, (np.floating, float)):
        v = float(obj)
        if math.isnan(v) or math.isinf(v):
            return 0.0
        return v
    if isinstance(obj, (np.bool_,)):
        return bool(obj)
    if isinstance(obj, (np.ndarray,)):
        return [_sanitize(x) for x in obj.tolist()]
    if isinstance(obj, dict):
        return {k: _sanitize(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_sanitize(v) for v in obj]
    return obj


def create_app(bot=None) -> FastAPI:
    global _bot_instance
    _bot_instance = bot

    app = FastAPI(
        title="Trading Bot Dashboard",
        description="Real-time crypto trading bot dashboard",
        version="1.0.0",
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.get("/", response_class=HTMLResponse)
    async def dashboard():
        return HTMLResponse(content=_get_dashboard_html())

    @app.get("/api/status")
    async def get_status():
        if _bot_instance is None:
            return {
                "running": False,
                "balance": 10000,
                "equity": 10000,
                "total_return_pct": 0,
                "drawdown": 0,
                "win_rate": 0,
                "total_trades": 0,
                "open_positions": {},
                "recent_trades": [],
                "paper_mode": True,
                "strategy": "hybrid",
                "symbols": ["BTC/USDT", "ETH/USDT"],
            }
        return _bot_instance.get_status()

    @app.get("/api/backtest/{symbol}")
    async def run_backtest(symbol: str, strategy: str = "hybrid"):
        """Run a quick backtest and return results."""
        try:
            from trading_bot.exchange import ExchangeConnector
            from trading_bot.strategies import STRATEGIES
            from trading_bot.backtesting import Backtester

            exchange = ExchangeConnector()
            df = exchange.fetch_ohlcv(symbol.replace("-", "/"), limit=500)
            strat_class = STRATEGIES.get(strategy)
            if not strat_class:
                raise HTTPException(404, f"Strategy '{strategy}' not found")
            backtester = Backtester(strat_class())
            result = backtester.run(df, symbol.replace("-", "/"))
            payload = _sanitize({
                "symbol": result.symbol,
                "strategy": result.strategy_name,
                "total_return_pct": result.total_return_pct,
                "annualized_return_pct": result.annualized_return_pct,
                "max_drawdown_pct": result.max_drawdown_pct,
                "sharpe_ratio": result.sharpe_ratio,
                "sortino_ratio": result.sortino_ratio,
                "calmar_ratio": result.calmar_ratio,
                "win_rate": result.win_rate,
                "total_trades": result.total_trades,
                "profit_factor": result.profit_factor,
                "equity_curve": result.equity_curve[-200:],
            })
            return JSONResponse(content=payload)
        except HTTPException:
            raise
        except Exception as exc:
            logger.exception("Backtest error for %s/%s: %s", symbol, strategy, exc)
            raise HTTPException(500, detail=str(exc))

    @app.get("/api/signals/{symbol}")
    async def get_signals(symbol: str, strategy: str = "hybrid"):
        """Generate signal for a symbol."""
        try:
            from trading_bot.exchange import ExchangeConnector
            from trading_bot.strategies import STRATEGIES

            exchange = ExchangeConnector()
            df = exchange.fetch_ohlcv(symbol.replace("-", "/"), limit=300)
            strat_class = STRATEGIES.get(strategy)
            if not strat_class:
                raise HTTPException(404, f"Strategy '{strategy}' not found")
            sig = strat_class().generate_signal(df, symbol.replace("-", "/"))
            payload = _sanitize({
                "symbol": sig.symbol,
                "signal": sig.signal_type.value,
                "confidence": sig.confidence,
                "price": sig.price,
                "stop_loss": sig.stop_loss,
                "take_profit": sig.take_profit,
                "strategy": sig.strategy_name,
                "metadata": sig.metadata,
            })
            return JSONResponse(content=payload)
        except HTTPException:
            raise
        except Exception as exc:
            logger.exception("Signal error for %s/%s: %s", symbol, strategy, exc)
            raise HTTPException(500, detail=str(exc))

    @app.get("/api/strategies")
    async def list_strategies():
        from trading_bot.strategies import STRATEGIES
        return {"strategies": list(STRATEGIES.keys())}

    return app


def _get_dashboard_html() -> str:
    return """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>🤖 Trading Bot Dashboard</title>
  <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
  <style>
    :root {
      --bg: #0d1117; --card: #161b22; --border: #30363d;
      --text: #e6edf3; --muted: #8b949e; --green: #3fb950;
      --red: #f85149; --blue: #58a6ff; --gold: #d29922;
      --purple: #bc8cff; --cyan: #39c5cf;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { background: var(--bg); color: var(--text); font-family: 'Segoe UI', system-ui, sans-serif; min-height: 100vh; }
    header { background: var(--card); border-bottom: 1px solid var(--border); padding: 16px 32px; display: flex; align-items: center; gap: 16px; }
    header h1 { font-size: 1.4rem; font-weight: 700; }
    .badge { background: #238636; color: #fff; padding: 3px 10px; border-radius: 20px; font-size: 0.75rem; font-weight: 600; }
    .badge.paper { background: #1f6feb; }
    .container { max-width: 1400px; margin: 0 auto; padding: 24px; }
    .grid { display: grid; gap: 16px; }
    .grid-4 { grid-template-columns: repeat(4, 1fr); }
    .grid-2 { grid-template-columns: repeat(2, 1fr); }
    .grid-3 { grid-template-columns: repeat(3, 1fr); }
    @media (max-width: 900px) { .grid-4,.grid-2,.grid-3 { grid-template-columns: 1fr 1fr; } }
    @media (max-width: 600px) { .grid-4,.grid-2,.grid-3 { grid-template-columns: 1fr; } }
    .card { background: var(--card); border: 1px solid var(--border); border-radius: 12px; padding: 20px; }
    .card h3 { font-size: 0.8rem; color: var(--muted); text-transform: uppercase; letter-spacing: 1px; margin-bottom: 10px; }
    .metric { font-size: 2rem; font-weight: 700; }
    .metric.green { color: var(--green); }
    .metric.red { color: var(--red); }
    .metric.blue { color: var(--blue); }
    .metric.gold { color: var(--gold); }
    .sub { font-size: 0.85rem; color: var(--muted); margin-top: 4px; }
    .chart-container { position: relative; height: 300px; }
    table { width: 100%; border-collapse: collapse; font-size: 0.875rem; }
    th { text-align: left; color: var(--muted); padding: 8px 12px; border-bottom: 1px solid var(--border); font-weight: 500; font-size: 0.75rem; text-transform: uppercase; }
    td { padding: 10px 12px; border-bottom: 1px solid var(--border); }
    tr:last-child td { border-bottom: none; }
    .tag { display: inline-flex; align-items: center; gap: 4px; padding: 2px 8px; border-radius: 4px; font-size: 0.75rem; font-weight: 600; }
    .tag.buy { background: rgba(63,185,80,.15); color: var(--green); }
    .tag.sell { background: rgba(248,81,73,.15); color: var(--red); }
    .tag.hold { background: rgba(139,148,158,.15); color: var(--muted); }
    .signal-panel { display: flex; gap: 12px; flex-wrap: wrap; }
    .signal-card { flex: 1; min-width: 160px; background: var(--bg); border: 1px solid var(--border); border-radius: 8px; padding: 14px; }
    .btn { background: var(--blue); color: #fff; border: none; padding: 8px 18px; border-radius: 8px; cursor: pointer; font-size: 0.875rem; font-weight: 600; transition: opacity .2s; }
    .btn:hover { opacity: .8; }
    .btn.green { background: var(--green); }
    .controls { display: flex; gap: 12px; flex-wrap: wrap; align-items: center; margin-bottom: 16px; }
    select { background: var(--card); color: var(--text); border: 1px solid var(--border); padding: 8px 12px; border-radius: 8px; font-size: 0.875rem; }
    .live-dot { width: 8px; height: 8px; border-radius: 50%; background: var(--green); animation: pulse 2s infinite; display: inline-block; }
    @keyframes pulse { 0%,100% { opacity: 1; } 50% { opacity: .3; } }
    .section-title { font-size: 1.1rem; font-weight: 700; margin: 24px 0 12px; display: flex; align-items: center; gap: 8px; }
    .pos-row td:first-child { font-weight: 600; color: var(--blue); }
    .profit { color: var(--green); }
    .loss { color: var(--red); }
    footer { text-align: center; padding: 24px; color: var(--muted); font-size: 0.8rem; border-top: 1px solid var(--border); margin-top: 48px; }
  </style>
</head>
<body>
  <header>
    <span style="font-size:1.8rem">🤖</span>
    <h1>Trading Bot Dashboard</h1>
    <span class="badge paper" id="mode-badge">PAPER</span>
    <span class="badge" id="strategy-badge" style="background:#6e40c9">HYBRID</span>
    <div style="margin-left:auto;display:flex;align-items:center;gap:8px">
      <span class="live-dot"></span>
      <span style="color:var(--muted);font-size:.85rem" id="last-update">Connecting...</span>
    </div>
  </header>

  <div class="container">
    <!-- KPI Cards -->
    <div class="section-title">📊 Portfolio Overview</div>
    <div class="grid grid-4" style="margin-bottom:16px">
      <div class="card"><h3>Equity</h3><div class="metric blue" id="kpi-equity">$0</div><div class="sub" id="kpi-balance">Balance: $0</div></div>
      <div class="card"><h3>Total Return</h3><div class="metric" id="kpi-return">0.00%</div><div class="sub" id="kpi-initial">Initial: $0</div></div>
      <div class="card"><h3>Max Drawdown</h3><div class="metric" id="kpi-drawdown">0.00%</div><div class="sub">Current risk exposure</div></div>
      <div class="card"><h3>Win Rate</h3><div class="metric gold" id="kpi-winrate">0.0%</div><div class="sub" id="kpi-trades">0 total trades</div></div>
    </div>

    <!-- Charts -->
    <div class="grid grid-2" style="margin-bottom:16px">
      <div class="card">
        <h3>Equity Curve</h3>
        <div class="chart-container"><canvas id="equityChart"></canvas></div>
      </div>
      <div class="card">
        <h3>Trade P&amp;L Distribution</h3>
        <div class="chart-container"><canvas id="pnlChart"></canvas></div>
      </div>
    </div>

    <!-- Backtest & Signals -->
    <div class="section-title">🔬 Backtest & Signals</div>
    <div class="controls">
      <select id="bt-symbol">
        <option>BTC/USDT</option><option>ETH/USDT</option>
        <option>BNB/USDT</option><option>SOL/USDT</option>
        <option>XRP/USDT</option>
      </select>
      <select id="bt-strategy">
        <option value="hybrid">Hybrid</option>
        <option value="rsi">RSI</option>
        <option value="macd">MACD</option>
        <option value="bollinger">Bollinger Bands</option>
        <option value="ema_crossover">EMA Crossover</option>
      </select>
      <button class="btn" onclick="runBacktest()">Run Backtest</button>
      <button class="btn green" onclick="getSignal()">Get Signal</button>
    </div>

    <div id="backtest-result" style="display:none" class="card" style="margin-bottom:16px">
      <h3 id="bt-title">Backtest Result</h3>
      <div class="grid grid-4" style="margin-top:12px" id="bt-metrics"></div>
      <div class="chart-container" style="margin-top:16px;height:200px"><canvas id="btChart"></canvas></div>
    </div>

    <div id="signal-result" style="display:none;margin-top:12px" class="card">
      <h3 id="sig-title">Signal</h3>
      <div class="signal-panel" id="signal-details" style="margin-top:12px"></div>
    </div>

    <!-- Open Positions -->
    <div class="section-title">📂 Open Positions</div>
    <div class="card" style="margin-bottom:16px">
      <table>
        <thead><tr><th>Symbol</th><th>Side</th><th>Entry</th><th>Qty</th><th>Unrealized PnL</th><th>PnL %</th></tr></thead>
        <tbody id="positions-body"><tr><td colspan="6" style="text-align:center;color:var(--muted);padding:24px">No open positions</td></tr></tbody>
      </table>
    </div>

    <!-- Recent Trades -->
    <div class="section-title">📋 Recent Trades</div>
    <div class="card">
      <table>
        <thead><tr><th>Symbol</th><th>Side</th><th>Entry</th><th>Exit</th><th>PnL</th><th>PnL %</th><th>Reason</th></tr></thead>
        <tbody id="trades-body"><tr><td colspan="7" style="text-align:center;color:var(--muted);padding:24px">No trades yet</td></tr></tbody>
      </table>
    </div>
  </div>
  <footer>Trading Bot v1.0 · Paper Trading Mode · Not Financial Advice</footer>

<script>
let equityChart, pnlChart, btChart;
const fmt = (n, d=2) => n?.toFixed(d) ?? '—';
const fmtMoney = n => '$' + (n||0).toLocaleString('en-US', {minimumFractionDigits:2, maximumFractionDigits:2});
const fmtPct = n => (n >= 0 ? '+' : '') + fmt(n) + '%';
const colorClass = n => n >= 0 ? 'profit' : 'loss';

function initCharts() {
  const defaults = { responsive: true, maintainAspectRatio: false,
    plugins: { legend: { labels: { color: '#8b949e' } } },
    scales: { x: { ticks: { color: '#8b949e' }, grid: { color: '#21262d' } },
              y: { ticks: { color: '#8b949e' }, grid: { color: '#21262d' } } } };

  equityChart = new Chart(document.getElementById('equityChart'), {
    type: 'line',
    data: { labels: [], datasets: [{ label: 'Equity ($)', data: [], borderColor: '#58a6ff',
      backgroundColor: 'rgba(88,166,255,.08)', fill: true, tension: 0.4, pointRadius: 0 }] },
    options: { ...defaults, plugins: { ...defaults.plugins, legend: { display: false } } }
  });

  pnlChart = new Chart(document.getElementById('pnlChart'), {
    type: 'bar',
    data: { labels: [], datasets: [{ label: 'PnL %', data: [],
      backgroundColor: ctx => ctx.raw >= 0 ? 'rgba(63,185,80,.7)' : 'rgba(248,81,73,.7)' }] },
    options: { ...defaults, plugins: { ...defaults.plugins, legend: { display: false } } }
  });
}

async function fetchStatus() {
  const r = await fetch('/api/status');
  const d = await r.json();

  // Mode badges
  document.getElementById('mode-badge').textContent = d.paper_mode ? 'PAPER' : 'LIVE';
  document.getElementById('strategy-badge').textContent = (d.strategy||'hybrid').toUpperCase();

  // KPIs
  const retEl = document.getElementById('kpi-return');
  retEl.textContent = fmtPct(d.total_return_pct || 0);
  retEl.className = 'metric ' + (d.total_return_pct >= 0 ? 'green' : 'red');
  document.getElementById('kpi-equity').textContent = fmtMoney(d.equity);
  document.getElementById('kpi-balance').textContent = 'Balance: ' + fmtMoney(d.balance);
  const ddEl = document.getElementById('kpi-drawdown');
  ddEl.textContent = fmt((d.drawdown||0)*100) + '%';
  ddEl.className = 'metric ' + ((d.drawdown||0) > 0.05 ? 'red' : 'green');
  document.getElementById('kpi-winrate').textContent = fmt((d.win_rate||0)*100, 1) + '%';
  document.getElementById('kpi-trades').textContent = (d.total_trades||0) + ' total trades';

  // Equity curve
  if (d.equity_curve && d.equity_curve.length > 0) {
    equityChart.data.labels = d.equity_curve.map((_, i) => i);
    equityChart.data.datasets[0].data = d.equity_curve;
    equityChart.update('none');
  }

  // PnL chart from recent trades
  const trades = d.recent_trades || [];
  pnlChart.data.labels = trades.map((t, i) => `#${i+1} ${t.symbol}`);
  pnlChart.data.datasets[0].data = trades.map(t => +(t.pnl_pct * 100).toFixed(2));
  pnlChart.update('none');

  // Open positions
  const posBody = document.getElementById('positions-body');
  const positions = Object.entries(d.open_positions || {});
  if (positions.length === 0) {
    posBody.innerHTML = '<tr><td colspan="6" style="text-align:center;color:var(--muted);padding:24px">No open positions</td></tr>';
  } else {
    posBody.innerHTML = positions.map(([sym, p]) => `
      <tr class="pos-row">
        <td>${sym}</td>
        <td><span class="tag ${p.side==='long'?'buy':'sell'}">${p.side.toUpperCase()}</span></td>
        <td>${fmtMoney(p.entry_price)}</td>
        <td>${(p.quantity||0).toFixed(6)}</td>
        <td class="${colorClass(p.unrealized_pnl)}">${fmtMoney(p.unrealized_pnl)}</td>
        <td class="${colorClass(p.pnl_pct)}">${fmtPct((p.pnl_pct||0)*100)}</td>
      </tr>`).join('');
  }

  // Recent trades table
  const trBody = document.getElementById('trades-body');
  if (trades.length === 0) {
    trBody.innerHTML = '<tr><td colspan="7" style="text-align:center;color:var(--muted);padding:24px">No trades yet</td></tr>';
  } else {
    trBody.innerHTML = [...trades].reverse().map(t => `
      <tr>
        <td style="font-weight:600;color:var(--blue)">${t.symbol}</td>
        <td><span class="tag ${t.side==='long'?'buy':'sell'}">${(t.side||'').toUpperCase()}</span></td>
        <td>${fmtMoney(t.entry)}</td>
        <td>${fmtMoney(t.exit)}</td>
        <td class="${colorClass(t.pnl)}">${fmtMoney(t.pnl)}</td>
        <td class="${colorClass(t.pnl_pct)}">${fmtPct((t.pnl_pct||0)*100)}</td>
        <td style="color:var(--muted);font-size:.8rem">${t.reason||''}</td>
      </tr>`).join('');
  }

  document.getElementById('last-update').textContent = 'Updated ' + new Date().toLocaleTimeString();
}

async function runBacktest() {
  const sym = document.getElementById('bt-symbol').value.replace('/','-');
  const strat = document.getElementById('bt-strategy').value;
  document.getElementById('backtest-result').style.display = 'none';
  try {
    const r = await fetch(`/api/backtest/${sym}?strategy=${strat}`);
    const d = await r.json();
    document.getElementById('bt-title').textContent = `Backtest: ${d.strategy?.toUpperCase()} on ${d.symbol}`;
    document.getElementById('bt-metrics').innerHTML = [
      ['Return', fmtPct(d.total_return_pct), d.total_return_pct >= 0 ? 'green' : 'red'],
      ['Sharpe', fmt(d.sharpe_ratio, 3), 'blue'],
      ['Win Rate', fmt((d.win_rate||0)*100, 1)+'%', 'gold'],
      ['Max DD', fmt(d.max_drawdown_pct, 2)+'%', 'red'],
      ['Trades', d.total_trades, 'blue'],
      ['Profit Factor', fmt(d.profit_factor, 2), d.profit_factor>=1?'green':'red'],
      ['Ann. Return', fmtPct(d.annualized_return_pct), d.annualized_return_pct>=0?'green':'red'],
      ['Calmar', fmt(d.calmar_ratio,2), 'gold'],
    ].map(([l,v,c]) => `<div><h3 style="font-size:.7rem;color:var(--muted)">${l}</h3><div class="metric ${c}" style="font-size:1.3rem">${v}</div></div>`).join('');

    if (btChart) btChart.destroy();
    btChart = new Chart(document.getElementById('btChart'), {
      type: 'line',
      data: { labels: (d.equity_curve||[]).map((_,i)=>i),
        datasets: [{ label: 'Equity', data: d.equity_curve||[], borderColor: '#3fb950',
          backgroundColor: 'rgba(63,185,80,.08)', fill: true, tension: 0.4, pointRadius: 0 }] },
      options: { responsive:true, maintainAspectRatio:false,
        plugins:{legend:{display:false}},
        scales:{x:{display:false},y:{ticks:{color:'#8b949e'},grid:{color:'#21262d'}}} }
    });
    document.getElementById('backtest-result').style.display = 'block';
  } catch(e) { alert('Backtest error: ' + e.message); }
}

async function getSignal() {
  const sym = document.getElementById('bt-symbol').value.replace('/','-');
  const strat = document.getElementById('bt-strategy').value;
  document.getElementById('signal-result').style.display = 'none';
  try {
    const r = await fetch(`/api/signals/${sym}?strategy=${strat}`);
    const d = await r.json();
    const signalColors = {STRONG_BUY:'#3fb950',BUY:'#58a6ff',HOLD:'#8b949e',SELL:'#f85149',STRONG_SELL:'#da3633'};
    const signalEmoji = {STRONG_BUY:'💚',BUY:'🟢',HOLD:'⚪',SELL:'🔴',STRONG_SELL:'❤️'};
    document.getElementById('sig-title').textContent = `Signal: ${d.symbol} (${d.strategy?.toUpperCase()})`;
    document.getElementById('signal-details').innerHTML = [
      ['Signal', `<span style="color:${signalColors[d.signal]};font-size:1.1rem;font-weight:700">${signalEmoji[d.signal]||''} ${d.signal}</span>`],
      ['Price', fmtMoney(d.price)],
      ['Confidence', fmt((d.confidence||0)*100, 1)+'%'],
      ['Stop Loss', d.stop_loss ? fmtMoney(d.stop_loss) : '—'],
      ['Take Profit', d.take_profit ? fmtMoney(d.take_profit) : '—'],
    ].map(([l,v]) => `<div class="signal-card"><div style="font-size:.75rem;color:var(--muted);margin-bottom:6px">${l}</div><div>${v}</div></div>`).join('');
    document.getElementById('signal-result').style.display = 'block';
  } catch(e) { alert('Signal error: ' + e.message); }
}

initCharts();
fetchStatus();
setInterval(fetchStatus, 5000);
</script>
</body>
</html>"""
