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

    // Individual Database Settings
    const [swissThreshold, setSwissThreshold] = useState(0.1)
    const [ppb3Threshold, setPpb3Threshold] = useState(0.5)
    const [seaThreshold, setSeaThreshold] = useState(0.4)
    const [seaPval, setSeaPval] = useState(0.00001)
    const [runSwiss, setRunSwiss] = useState(true)
    const [runSEA, setRunSEA] = useState(true)
    const [runPPB3, setRunPPB3] = useState(true)
    const [maxCompounds, setMaxCompounds] = useState(0)

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

        console.log('Starting upload for:', file.name)
        const formData = new FormData()
        formData.append('file', file)

        try {
            const response = await axios.post(`${API_BASE}/upload`, formData)
            console.log('Upload success:', response.data)
            setUploadedFilename(response.data.filename)
            setMessage({ type: 'success', text: `Uploaded: ${response.data.filename}` })
        } catch (err) {
            console.error('Upload failed:', err)
            const errorMsg = err.response?.data?.detail || err.message || 'Upload failed'
            setMessage({ type: 'error', text: `Error: ${errorMsg}` })
        }
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
            showLabels, ppiFilter, dpi, minProbability, diseaseInput,
            swissThreshold, ppb3Threshold, seaThreshold, seaPval,
            runSwiss, runSEA, runPPB3, maxCompounds,
            filename: uploadedFilename
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

    const handleReset = async () => {
        try {
            await axios.post(`${API_BASE}/reset`)
            setIsRunning(false)
            if (eventSourceRef.current) eventSourceRef.current.close()
            setMessage({ type: 'success', text: 'Pipeline state reset' })
        } catch (err) {
            setMessage({ type: 'error', text: 'Reset failed' })
        }
    }

    const handleExport = (format) => {
        if (!activePlot) return
        const base = activePlot.url.substring(0, activePlot.url.lastIndexOf('.'))
        window.open(`${base}.${format}`, '_blank')
    }

    // --- RENDER HELPERS ---
    const renderResultsSidebar = () => {
        const byExt = results.reduce((acc, f) => {
            const ext = f.name.split('.').pop().toUpperCase()
            if (!acc[ext]) acc[ext] = []
            acc[ext].push(f)
            return acc
        }, {})

        return (
            <div className="results-browser">
                <hr style={{ margin: '20px 0', border: '0', borderTop: '1px solid #eee' }} />
                <h3>📦 Result Assets</h3>

                {Object.keys(byExt).sort().map(ext => (
                    <details key={ext} open={ext === 'PNG'}>
                        <summary>{ext} Files ({byExt[ext].length})</summary>
                        <div className="asset-list">
                            {byExt[ext].map((f, i) => (
                                <div
                                    key={i}
                                    className={`asset-item ${activePlot?.url === f.url ? 'active' : ''}`}
                                    onClick={() => {
                                        setActivePlot(f)
                                        const el = document.getElementById(`fig-${f.name}`)
                                        if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' })
                                    }}
                                >
                                    <div className="asset-info">
                                        <span className="asset-name" title={f.name}>{f.name.replace(/_/g, ' ')}</span>
                                    </div>
                                    <div className="asset-actions">
                                        <a href={f.url} download onClick={(e) => e.stopPropagation()} className="download-icon" title="Download Asset">📥</a>
                                    </div>
                                </div>
                            ))}
                        </div>
                    </details>
                ))}
            </div>
        )
    }

    const renderSidebar = () => (
        <aside className="controls-panel">
            <div className="control-section">
                <h3>📁 Data Source</h3>
                <div className="input-group">
                    <input type="file" onChange={handleFileChange} disabled={isRunning} />
                    <button className="btn btn-secondary" onClick={handleUpload} style={{ marginTop: '8px', width: '100%' }}>Upload CSV</button>
                </div>
                <div className="input-group">
                    <label>🔍 Disease Overlap (EFO IDs)</label>
                    <input type="text" value={diseaseInput} onChange={e => setDiseaseInput(e.target.value)} placeholder="EFO_0000305, etc." disabled={isRunning} />
                </div>
            </div>

            <div className="control-section">
                <h3>📊 Analysis Stats</h3>
                <div className="stats-grid">
                    <div className="stat-card minimal">
                        <span className="val">{stats.targets || 0}</span> <span className="lbl">Targets</span>
                    </div>
                    <div className="stat-card minimal">
                        <span className="val">{stats.pathways || 0}</span> <span className="lbl">Pathways</span>
                    </div>
                </div>
            </div>

            {renderResultsSidebar()}
        </aside>
    )

    return (
        <div className="dashboard">
            <header>
                <h1>🧬 NP-Bioinformatics Dashboard</h1>
                <div style={{ display: 'flex', gap: '10px' }}>
                    {isRunning && <div className="spinner"></div>}
                    <button className="btn btn-primary" onClick={() => startPipeline(false)} disabled={isRunning}>Run Pipeline</button>
                    <button className="btn btn-secondary" onClick={() => startPipeline(true)} disabled={isRunning}>Re-calculate</button>
                    <button className="btn btn-danger" onClick={handleReset} title="Clear stuck pipeline">Reset</button>
                </div>
            </header>

            <div className="main-content-area">
                {renderSidebar()}

                <main className="preview-panel">
                    <div className="preview-header">
                        <h2>{activePlot ? activePlot.name.replace(/_/g, ' ') : 'Plot Gallery'}</h2>
                        {activePlot && activePlot.type === 'image' && (
                            <div className="action-buttons">
                                <button className="btn btn-secondary" onClick={() => handleExport('png')}>PNG</button>
                                <button className="btn btn-secondary" onClick={() => handleExport('svg')}>SVG</button>
                                <button className="btn btn-secondary" onClick={() => handleExport('tiff')}>TIFF</button>
                            </div>
                        )}
                    </div>

                    <div className="preview-container">
                        <div className="vertical-plots-list">
                            {results.filter(f => f.type === 'image').map((f, i) => (
                                <div key={i} id={`fig-${f.name}`} className="preview-frame">
                                    <div className="frame-header">
                                        <span>{f.name.replace(/_/g, ' ')}</span>
                                        <div className="frame-actions">
                                            <a href={f.url} download className="btn-download-main">📥 Download {f.name.split('.').pop().toUpperCase()}</a>
                                        </div>
                                    </div>
                                    <img src={f.url} loading="lazy" alt={f.name} />
                                </div>
                            ))}
                        </div>

                        {results.length === 0 && (
                            <div className="no-preview">
                                🖼️ Pipeline results will appear here as a scrollable gallery
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
                </main>
            </div>

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
