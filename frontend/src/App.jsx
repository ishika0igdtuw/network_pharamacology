import { useState, useRef, useEffect, useCallback } from 'react'
import axios from 'axios'
import './App.css'

const API_BASE = 'http://localhost:8000'

function App() {
    // --- STATE ---
    const [file, setFile] = useState(null)
    const [uploadedFilename, setUploadedFilename] = useState('')
    const [logs, setLogs] = useState('')
    const [showLogs, setShowLogs] = useState(false)
    const [results, setResults] = useState([])
    const [isRunning, setIsRunning] = useState(false)
    const [progress, setProgress] = useState(0)
    const [progressMessage, setProgressMessage] = useState('')
    const [message, setMessage] = useState({ type: '', text: '' })
    const [activePlot, setActivePlot] = useState(null)
    const [stats, setStats] = useState({ herbs: 0, molecules: 0, targets: 0, pathways: 0 })

    // --- SETTINGS ---
    const [fontSize, setFontSize] = useState(14)
    const [fontStyle, setFontStyle] = useState('bold')
    const [fontFamily, setFontFamily] = useState('Helvetica')
    const [labelCase, setLabelCase] = useState('sentence')
    const [showLabels, setShowLabels] = useState(true)
    const [ppiFilter, setPpiFilter] = useState(2)
    const [dpi, setDpi] = useState(300)
    const [minProbability, setMinProbability] = useState(0.5)
    const [diseaseInput, setDiseaseInput] = useState('')

    const eventSourceRef = useRef(null)
    const logEndRef = useRef(null)

    // Scroll logs to bottom
    useEffect(() => {
        if (showLogs && logEndRef.current) {
            logEndRef.current.scrollIntoView({ behavior: 'smooth' })
        }
    }, [logs, showLogs])

    // Fetch results and update stats
    const fetchResults = useCallback(async () => {
        try {
            const response = await axios.get(`${API_BASE}/results`)
            const files = response.data.files
            setResults(files)

            // Auto-select the first large network or interesting plot
            const bestPreview = files.find(f => f.category === 'integrated_network') || files.find(f => f.type === 'image')
            if (bestPreview) setActivePlot(bestPreview)

            // Dynamic Stats Calculation
            const tcmInput = files.find(f => f.name === 'tcm_input.csv')
            if (tcmInput && tcmInput.csv_meta) {
                // Actually need more complex logic to count unique herbs/mols/targets
                // For now, let's use the row count or mock if meta isn't detailed enough
                setStats({
                    herbs: 'Loading...',
                    molecules: 'Loading...',
                    targets: tcmInput.csv_meta.rows,
                    pathways: files.filter(f => f.category === 'pathway_map').length
                })
            }
        } catch (error) {
            console.error('Failed to fetch results:', error)
        }
    }, [])

    // --- HANDLERS ---
    const handleFileChange = (e) => setFile(e.target.files[0])

    const handleUpload = async () => {
        if (!file) return setMessage({ type: 'error', text: 'Please select a file' })
        const formData = new FormData()
        formData.append('file', file)
        try {
            const response = await axios.post(`${API_BASE}/upload`, formData)
            setUploadedFilename(response.data.filename)
            setMessage({ type: 'success', text: `Uploaded: ${response.data.filename}` })
        } catch (err) { setMessage({ type: 'error', text: 'Upload failed' }) }
    }

    const startPipeline = (isReanalyze = false) => {
        if (!uploadedFilename && !isReanalyze) return setMessage({ type: 'error', text: 'Upload data first' })

        setIsRunning(true)
        setProgress(0)
        setProgressMessage(isReanalyze ? 'Re-analyzing...' : 'Starting Pipeline...')
        setLogs(isReanalyze ? 'Initializing re-analysis...\n' : 'Initializing full pipeline...\n')
        setShowLogs(true)

        if (eventSourceRef.current) eventSourceRef.current.close()

        const params = new URLSearchParams({
            fontSize, fontStyle, fontFamily, labelCase,
            showLabels, ppiFilter, dpi, minProbability, diseaseInput
        })

        const endpoint = isReanalyze ? 'reanalyze' : 'run-stream'
        const eventSource = new EventSource(`${API_BASE}/${endpoint}?${params.toString()}`)
        eventSourceRef.current = eventSource

        eventSource.onmessage = (event) => {
            const data = event.data
            if (data === 'DONE') {
                eventSource.close()
                setIsRunning(false)
                setProgress(100)
                fetchResults()
                return
            }
            if (data.startsWith('PROGRESS:')) {
                const [_, pct, msg] = data.split(':')
                setProgress(parseInt(pct))
                setProgressMessage(msg)
            } else {
                setLogs(prev => prev + data)
            }
        }
        eventSource.onerror = () => {
            eventSource.close()
            setIsRunning(false)
            setMessage({ type: 'error', text: 'Connection lost' })
        }
    }

    const handleExport = (format) => {
        if (!activePlot) return
        const base = activePlot.url.substring(0, activePlot.url.lastIndexOf('.'))
        window.open(`${base}.${format}`, '_blank')
    }

    // --- RENDER HELPERS ---
    const renderSidebar = () => (
        <aside className="controls-panel">
            <div className="control-section">
                <h3>📁 Data Source</h3>
                <div className="input-group">
                    <input type="file" onChange={handleFileChange} disabled={isRunning} />
                    <button className="btn btn-secondary" onClick={handleUpload} style={{ marginTop: '8px', width: '100%' }}>Upload CSV</button>
                </div>
                <div className="input-group">
                    <label>🔍 Disease Overlap (EFO IDs, comma separated)</label>
                    <input
                        type="text"
                        placeholder="e.g. EFO_0000305, EFO_0000311"
                        value={diseaseInput}
                        onChange={e => setDiseaseInput(e.target.value)}
                        disabled={isRunning}
                    />
                    <small style={{ color: '#666', fontSize: '0.75rem' }}>Supports Multi-set Venn (2-4 sets) & Intersection CSVs</small>
                </div>
            </div>

            <div className="control-section">
                <h3>🎚️ Interaction Filter</h3>
                <div className="input-group">
                    <label>Min. Confidence Score ({minProbability})</label>
                    <input
                        type="range" min="0.1" max="1.0" step="0.05"
                        value={minProbability}
                        onChange={e => setMinProbability(parseFloat(e.target.value))}
                        disabled={isRunning}
                    />
                </div>
                <div className="input-group">
                    <label>PPI Hub Filter (Min Degree: {ppiFilter})</label>
                    <input
                        type="range" min="1" max="20" step="1"
                        value={ppiFilter}
                        onChange={e => setPpiFilter(parseInt(e.target.value))}
                        disabled={isRunning}
                    />
                </div>
            </div>

            <div className="control-section">
                <h3>🎨 Visual Style</h3>
                <div className="input-group">
                    <label>Font Family</label>
                    <select value={fontFamily} onChange={e => setFontFamily(e.target.value)} disabled={isRunning}>
                        <option value="Helvetica">Helvetica / Arial</option>
                        <option value="Times">Times New Roman</option>
                        <option value="Courier">Monospace (Courier)</option>
                    </select>
                </div>
                <div className="input-group">
                    <label>Label Case</label>
                    <select value={labelCase} onChange={e => setLabelCase(e.target.value)} disabled={isRunning}>
                        <option value="sentence">Sentence case</option>
                        <option value="upper">UPPERCASE</option>
                        <option value="title">Title Case</option>
                    </select>
                </div>
                <div className="input-group" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <input type="checkbox" checked={showLabels} onChange={e => setShowLabels(e.target.checked)} disabled={isRunning} />
                    <label style={{ margin: 0 }}>Show Node Labels</label>
                </div>
            </div>

            <div className="control-section">
                <h3>⚙️ Export Settings</h3>
                <div className="input-group">
                    <label>DPI (Resolution)</label>
                    <select value={dpi} onChange={e => setDpi(parseInt(e.target.value))} disabled={isRunning}>
                        <option value="72">72 (Screen)</option>
                        <option value="300">300 (Standard)</option>
                        <option value="600">600 (Publication)</option>
                    </select>
                </div>
            </div>
        </aside>
    )

    const renderStats = () => (
        <aside className="stats-panel">
            <h3>📊 Analysis Stats</h3>
            <div className="stat-card">
                <div className="stat-value">{stats.targets || 0}</div>
                <div className="stat-label">Predicted Targets</div>
            </div>
            <div className="stat-card">
                <div className="stat-value">{stats.pathways || 0}</div>
                <div className="stat-label">Enriched Pathways</div>
            </div>

            <h3 style={{ marginTop: '30px' }}>📦 Quick Assets</h3>
            <div className="asset-list">
                {results.slice(0, 15).map((f, i) => (
                    <div key={i} className="asset-item">
                        <a href={f.url} target="_blank" rel="noreferrer" title={f.name}>{f.name}</a>
                        <span style={{ fontSize: '0.7rem', color: '#999' }}>{f.type.toUpperCase()}</span>
                    </div>
                ))}
            </div>
        </aside>
    )

    return (
        <div className="dashboard">
            <header>
                <h1>🧬 NP-Bioinformatics Dashboard</h1>
                <div style={{ display: 'flex', gap: '10px' }}>
                    {isRunning && <div className="spinner"></div>}
                    <button className="btn btn-primary" onClick={() => startPipeline(false)} disabled={isRunning}>Run Pipeline</button>
                    <button className="btn btn-secondary" onClick={() => startPipeline(true)} disabled={isRunning || results.length === 0}>Re-calculate</button>
                </div>
            </header>

            {renderSidebar()}

            <main className="preview-panel">
                <div className="preview-header">
                    <h2>{activePlot ? activePlot.name : 'Plot Preview'}</h2>
                    {activePlot && (
                        <div className="action-buttons">
                            <button className="btn btn-secondary" onClick={() => handleExport('png')}>PNG</button>
                            <button className="btn btn-secondary" onClick={() => handleExport('svg')}>SVG</button>
                            <button className="btn btn-secondary" onClick={() => handleExport('tiff')}>TIFF</button>
                        </div>
                    )}
                </div>

                <div className="preview-container">
                    {activePlot ? (
                        activePlot.type === 'image' ? (
                            <img src={activePlot.url} className="preview-image" alt="Preview" />
                        ) : (
                            <div className="no-preview">
                                📄 CSV data table uploaded. View in stats or download.
                                <a href={activePlot.url} className="btn btn-primary" target="_blank" rel="noreferrer" download>Open CSV</a>
                            </div>
                        )
                    ) : (
                        <div className="no-preview">
                            🖼️ Select a plot below to preview
                        </div>
                    )}

                    {isRunning && (
                        <div className="overlay">
                            <div className="progress-bar">
                                <div className="progress-value" style={{ width: `${progress}%` }}></div>
                            </div>
                            <div style={{ fontWeight: 'bold', color: '#555' }}>{progressMessage}</div>
                        </div>
                    )}
                </div>

                <div className="plots-grid">
                    {results.filter(f => f.type === 'image').map((f, i) => (
                        <div key={i} className={`plot-thumb ${activePlot?.url === f.url ? 'active' : ''}`} onClick={() => setActivePlot(f)}>
                            <img src={f.url} alt={f.name} />
                        </div>
                    ))}
                </div>
            </main>

            {renderStats()}

            <footer>
                <div style={{ marginRight: 'auto', display: 'flex', gap: '20px' }}>
                    <span style={{ fontSize: '0.85rem', color: '#666' }}>
                        Threshold: <strong>{minProbability}</strong> | Font: <strong>{fontFamily}</strong>
                    </span>
                    {message.text && <span className={`message-pill ${message.type}`}>{message.text}</span>}
                </div>
                <button className="btn btn-secondary" onClick={() => setShowLogs(!showLogs)}>{showLogs ? 'Hide Console' : 'Show Console'}</button>
                <button className="btn btn-success" onClick={() => window.open(`${API_BASE}/download-all`)}>Download All (ZIP)</button>
            </footer>

            {showLogs && (
                <div className="log-modal">
                    <div className="log-header">
                        <span>SYSTEM CONSOLE</span>
                        <button onClick={() => setShowLogs(false)} style={{ background: 'none', border: 'none', color: 'white', cursor: 'pointer' }}>✕</button>
                    </div>
                    <div className="log-content">
                        {logs}
                        <div ref={logEndRef}></div>
                    </div>
                </div>
            )}
        </div>
    )
}

export default App
