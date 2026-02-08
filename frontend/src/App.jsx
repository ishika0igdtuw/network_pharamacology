import React, { useState, useEffect, useRef } from 'react'
import axios from 'axios'
import './App.css'

const API_BASE = 'http://localhost:8000'

const NAV_ITEMS = [
    { id: 'data', label: 'Data', icon: '📂' },
    { id: 'prediction', label: 'Target Prediction', icon: '🧪' },
    { id: 'network', label: 'Network Config', icon: '⚙️' },
    { id: 'network-viz', label: 'Network Viz', icon: '🕸' },
    { id: 'ppi', label: 'PPI', icon: '🔗' },
    { id: 'enrichment', label: 'Enrichment', icon: '📊' },
    { id: 'disease', label: 'Disease Overlap', icon: '🧬' },
]

function App() {
    const [activeTab, setActiveTab] = useState('data')
    const [showTerminal, setShowTerminal] = useState(false)
    const [logs, setLogs] = useState('')
    const [isRunning, setIsRunning] = useState(false)
    const [results, setResults] = useState([])
    const [activePlot, setActivePlot] = useState(null)
    const [zoomedImage, setZoomedImage] = useState(null)

    // Form States
    const [projectName, setProjectName] = useState('My Project')
    const [organism, setOrganism] = useState('Human')
    const [uploadedFilename, setUploadedFilename] = useState(null)
    const [validationData, setValidationData] = useState(null)
    const [uploadStatus, setUploadStatus] = useState('idle')
    const [previewTab, setPreviewTab] = useState('combined')
    const [enrichmentTab, setEnrichmentTab] = useState('kegg_enrichment')

    // Prediction/Summary States
    const [predictionSummary, setPredictionSummary] = useState(null)

    // Filtering/Network States - Initialized from localStorage if available
    const [swissThreshold, setSwissThreshold] = useState(() => parseFloat(localStorage.getItem('swissThreshold')) || 0.1)
    const [ppb3Threshold, setPpb3Threshold] = useState(() => parseFloat(localStorage.getItem('ppb3Threshold')) || 0.3)
    const [seaThreshold, setSeaThreshold] = useState(() => parseFloat(localStorage.getItem('seaThreshold')) || 0.3)
    const [seaPval, setSeaPval] = useState(() => parseFloat(localStorage.getItem('seaPval')) || 1e-5)
    const [filterMode, setFilterMode] = useState('OR')
    const [filteredCount, setFilteredCount] = useState(0)
    const [maxValues, setMaxValues] = useState({ swiss: 1, ppb3: 1, sea: 1, seaPval: 1 })

    // Visual States - Persistence
    const [fontSize, setFontSize] = useState(() => parseInt(localStorage.getItem('fontSize')) || 14)
    const [fontStyle, setFontStyle] = useState(() => localStorage.getItem('fontStyle') || 'bold')
    const [dpi, setDpi] = useState(() => parseInt(localStorage.getItem('dpi')) || 300)

    // Other states
    const [layoutType, setLayoutType] = useState('kk')
    const [ppiDegreeFilter, setPpiDegreeFilter] = useState(2)
    const [ppiConfidence, setPpiConfidence] = useState(0.4)
    const [topNPathways, setTopNPathways] = useState(10)
    const [diseaseInput, setDiseaseInput] = useState('')

    // MISSING STATE ADDED HERE
    const [filterStats, setFilterStats] = useState({ count: 0, customFile: null })

    const eventSourceRef = useRef(null)
    const terminalEndRef = useRef(null)

    const addLog = (msg) => setLogs(prev => prev + `[${new Date().toLocaleTimeString()}] ${msg}\n`)

    useEffect(() => {
        if (terminalEndRef.current) {
            terminalEndRef.current.scrollIntoView({ behavior: 'smooth' })
        }
    }, [logs])

    // Specific effect to save threshold changes
    useEffect(() => {
        localStorage.setItem('swissThreshold', swissThreshold)
        localStorage.setItem('ppb3Threshold', ppb3Threshold)
        localStorage.setItem('seaThreshold', seaThreshold)
        localStorage.setItem('seaPval', seaPval)

        localStorage.setItem('fontSize', fontSize)
        localStorage.setItem('fontStyle', fontStyle)
        localStorage.setItem('dpi', dpi)
    }, [swissThreshold, ppb3Threshold, seaThreshold, seaPval, fontSize, fontStyle, dpi])

    const fetchResults = async () => {
        try {
            const res = await axios.get(`${API_BASE}/results`)
            if (res.data.files && res.data.files.length > 0) {
                setResults(res.data.files)
            } else if (!isRunning) {
                // Only clear if not running, to avoid flickering during analysis
                setResults([])
            }
        } catch (err) { console.error('Failed to fetch results:', err) }
    }

    const fetchAllResults = fetchResults // Re-use the same function

    const fetchPredictionSummary = async () => {
        try {
            const res = await axios.get(`${API_BASE}/prediction-summary`)
            if (res.data.status !== 'no_results') {
                setPredictionSummary(res.data)
                calculateMaxValues(res.data)
                calculateFilteredCount(res.data)
            }
        } catch (err) { console.error('Summary failed:', err) }
    }

    const calculateMaxValues = (summary) => {
        if (!summary || !summary.combined || !summary.combined.preview) return

        const data = summary.combined.preview
        let maxSwiss = 0, maxPpb3 = 0, maxSea = 0, maxPval = 0

        data.forEach(row => {
            if (row.Database === 'SwissTargetPrediction' && row.Probability) {
                maxSwiss = Math.max(maxSwiss, parseFloat(row.Probability) || 0)
            }
            if (row.Database === 'PPB3' && row.Probability) {
                maxPpb3 = Math.max(maxPpb3, parseFloat(row.Probability) || 0)
            }
            if (row.Database === 'SEA' && row.Max_Tc) {
                maxSea = Math.max(maxSea, parseFloat(row.Max_Tc) || 0)
            }
            if (row.Database === 'SEA' && row.P_Value && row.P_Value !== '-') {
                maxPval = Math.max(maxPval, parseFloat(row.P_Value) || 0)
            }
        })

        setMaxValues({
            swiss: maxSwiss > 0 ? maxSwiss : 1,
            ppb3: maxPpb3 > 0 ? maxPpb3 : 1,
            sea: maxSea > 0 ? maxSea : 1,
            seaPval: maxPval > 0 ? maxPval : 1
        })
    }

    const calculateFilteredCount = async (summary = predictionSummary) => {
        if (!summary || !summary.combined) {
            setFilteredCount(0)
            return
        }

        try {
            // Call backend to get actual filtered count from complete dataset
            const res = await axios.get(`${API_BASE}/filter-count`, {
                params: {
                    swiss: swissThreshold,
                    ppb3: ppb3Threshold,
                    sea: seaThreshold,
                    sea_pval: seaPval,
                    mode: filterMode
                }
            })
            setFilteredCount(res.data.count)
        } catch (err) {
            console.error('Failed to get filter count:', err)
            setFilteredCount(0)
        }
    }

    useEffect(() => {
        if (predictionSummary) {
            calculateFilteredCount()
        }
    }, [swissThreshold, ppb3Threshold, seaThreshold, seaPval, filterMode, predictionSummary])

    useEffect(() => {
        fetchResults()
        fetchPredictionSummary()
        const timer = setInterval(() => {
            fetchResults()
            if (activeTab === 'prediction') fetchPredictionSummary()
        }, 10000)
        return () => clearInterval(timer)
    }, [activeTab])

    const runStage = (stageName, endpoint, params) => {
        if (isRunning) {
            alert("A process is already running. Please Wait.")
            return
        }
        setIsRunning(true)
        setShowTerminal(true)
        setLogs(prev => prev + `>>> Starting Stage: ${stageName} [${new Date().toLocaleTimeString()}]\n`)

        let hasError = false
        const queryParams = new URLSearchParams({ ...params, filename: uploadedFilename }).toString()
        const eventSource = new EventSource(`${API_BASE}/${endpoint}?${queryParams}`)
        eventSourceRef.current = eventSource

        eventSource.onmessage = async (event) => {
            const data = event.data
            if (data.includes('ERROR:')) {
                hasError = true
            }

            if (data === 'DONE') {
                eventSource.close()
                setIsRunning(false)
                if (hasError) {
                    addLog(`✖ ${stageName} stopped due to errors.`)
                } else {
                    addLog(`✓ ${stageName} completed successfully.`)
                }
                const updatedResults = await axios.get(`${API_BASE}/results`)
                const files = updatedResults.data.files
                setResults(files)

                // Auto-select the newest result for the current stage
                if (files.length > 0) {
                    let catName = ''
                    if (stageName === 'Network Generation') catName = 'tcm_network'
                    if (stageName === 'PPI Analysis') catName = 'ppi'
                    if (stageName === 'Enrichment') catName = 'kegg_enrichment'

                    if (catName) {
                        const latest = files.find(f => f.category === catName)
                        if (latest) setActivePlot(latest)
                    }
                }

                if (activeTab === 'prediction' || stageName === 'Target Prediction') fetchPredictionSummary()
                if (activeTab === 'network' || stageName === 'Network Generation') updateFilterStats()
            } else if (data.startsWith('PROGRESS:')) {
                const parts = data.split(':')
                setLogs(prev => prev + `[PROGRESS] ${parts[2]}\n`)
            } else {
                setLogs(prev => prev + data + '\n')
            }
        }

        eventSource.onerror = () => {
            eventSource.close()
            setIsRunning(false)
            addLog(`✖ ERROR: ${stageName} failed.`)
        }
    }

    const stopProcess = async () => {
        if (!isRunning) return
        if (window.confirm("Stop the current analysis? This will kill the backend process.")) {
            try {
                await axios.get(`${API_BASE}/stop`)
                if (eventSourceRef.current) eventSourceRef.current.close()
                setIsRunning(false)
                addLog("!! User terminated the backend process.")
            } catch (err) {
                addLog("✖ Failed to stop process cleanly. Browser link closed.")
                if (eventSourceRef.current) eventSourceRef.current.close()
                setIsRunning(false)
            }
        }
    }

    const clearLogs = () => {
        if (isRunning) {
            alert("Cannot clear logs while a stage is running.")
            return
        }
        setLogs('')
    }

    const handleFileUpload = async (e) => {
        const selectedFile = e.target.files[0]
        if (!selectedFile) return
        setUploadStatus('uploading')
        setUploadedFilename(null)
        setValidationData(null)

        const formData = new FormData()
        formData.append('file', selectedFile)

        try {
            const valRes = await axios.post(`${API_BASE}/validate-csv`, formData)
            if (!valRes.data.valid) {
                setUploadStatus('error')
                addLog(`✖ CSV Validation Error: ${valRes.data.error || 'Check columns'}`)
                return
            }
            setValidationData(valRes.data)
            const uploadRes = await axios.post(`${API_BASE}/upload`, formData)
            setUploadedFilename(uploadRes.data.filename)
            setUploadStatus('success')
            addLog(`✓ Uploaded ${uploadRes.data.filename} (${valRes.data.rowCount} rows)`)
        } catch (err) {
            setUploadStatus('error')
            addLog(`✖ Upload failed. Check server connection.`)
        }
    }

    const updateFilterStats = async () => {
        try {
            const res = await axios.get(`${API_BASE}/filter-stats`, {
                params: {
                    swiss: swissThreshold || 0,
                    ppb3: ppb3Threshold || 0,
                    sea: seaThreshold || 0
                }
            })
            setFilterStats(prev => ({ ...prev, count: res.data.count }))
        } catch (err) { console.error('Filter stats failed:', err) }
    }

    const [uploadingNet, setUploadingNet] = useState(false)

    const handleNetworkUpload = async (e) => {
        e.preventDefault()
        e.stopPropagation()

        let file = null
        if (e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files.length > 0) {
            file = e.dataTransfer.files[0]
        } else if (e.target.files && e.target.files.length > 0) {
            file = e.target.files[0]
        }
        if (!file) return
        setUploadingNet(true)
        const formData = new FormData()
        formData.append('file', file)

        try {
            const res = await axios.post(`${API_BASE}/upload-network-input`, formData, {
                headers: { 'Content-Type': 'multipart/form-data' }
            })
            addLog(`✅ Uploaded Custom Network Input: ${res.data.filename}`)
            setFilterStats(prev => ({ ...prev, customFile: res.data.filename }))
            alert("File uploaded! The next 'Visualize Network' run will use this file as input.")
        } catch (err) {
            console.error('Upload Error:', err)
            const errorMsg = err.response?.data?.detail || err.message || 'Unknown error'
            addLog(`❌ Failed to upload network input: ${errorMsg}`)
            alert(`Upload failed: ${errorMsg}`)
        } finally {
            setUploadingNet(false)
        }
    }

    const WindowData = () => (
        <div className="window-card">
            <div className="window-header">
                <h2>Project Setup</h2>
                <p>Initialize your session and validate the master dataset.</p>
            </div>
            <div className="controls-grid">
                <div className="control-group">
                    <label>Project Name</label>
                    <input type="text" value={projectName} onChange={(e) => setProjectName(e.target.value)} />
                </div>
                <div className="control-group">
                    <label>Organism</label>
                    <select value={organism} onChange={(e) => setOrganism(e.target.value)}>
                        <option value="Human">Human (Homo sapiens)</option>
                        <option value="Mouse">Mouse</option>
                        <option value="Rat">Rat</option>
                    </select>
                </div>
            </div>
            <label className={`upload-zone ${uploadStatus}`}>
                <input type="file" onChange={handleFileUpload} hidden />
                <span className="upload-zone-icon">{uploadStatus === 'success' ? '✔' : '☁'}</span>
                <strong>{uploadedFilename || 'Click to upload Master Phytochemical CSV'}</strong>
                <p style={{ marginTop: '0.5rem', color: '#64748b' }}>Required: Phytochemical Name, Plant Source, SMILES</p>
            </label>
            {validationData && (
                <div style={{ marginTop: '2rem' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
                        <h3>Data Preview</h3>
                        <span style={{ fontSize: '0.8rem', color: '#64748b' }}>{validationData.rowCount} Rows Detected</span>
                    </div>
                    <div className="table-wrapper">
                        <table>
                            <thead><tr>{validationData.columns.slice(0, 5).map(c => <th key={c}>{c}</th>)}</tr></thead>
                            <tbody>{validationData.preview.map((row, i) => <tr key={i}>{validationData.columns.slice(0, 5).map(c => <td key={c}>{row[c] || '-'}</td>)}</tr>)}</tbody>
                        </table>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '2rem' }}>
                        <button className="btn btn-accent" onClick={() => setActiveTab('prediction')}>Go to Prediction Engines ➔</button>
                    </div>
                </div>
            )}
        </div>
    )

    const WindowPrediction = () => (
        <div className="window-card">
            <div className="window-header">
                <h2>Target Prediction Module</h2>
                <p>Generate raw Interaction mappings using SwissTarget, SEA, and PPB3.</p>
            </div>

            <div className="control-group" style={{ background: '#f5f3ff', borderColor: '#ddd6fe', marginBottom: '2rem' }}>
                <h3 style={{ marginBottom: '1rem', color: '#4338ca' }}>Engine Controls</h3>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <p style={{ fontSize: '0.85rem', margin: 0 }}>Selected Dataset: <strong style={{ color: '#4338ca' }}>{uploadedFilename}</strong></p>
                    <div style={{ display: 'flex', gap: '1rem' }}>
                        <button className="btn btn-primary" onClick={() => runStage('Target Prediction', 'run-stream', { stage: 'prediction' })} disabled={isRunning || !uploadedFilename}>
                            ⚡ {isRunning ? 'Analyzing...' : 'Start Prediction Engine'}
                        </button>
                        {isRunning && activeTab === 'prediction' && <button className="btn btn-secondary" style={{ color: '#ef4444', borderColor: '#fecaca' }} onClick={stopProcess}>Stop Session</button>}
                    </div>
                </div>
            </div>

            <div className="control-group" style={{ background: '#f0fdf4', borderColor: '#bbf7d0' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
                    <h3 style={{ color: '#15803d', margin: 0 }}>Prediction Results Explorer</h3>
                    {predictionSummary && (
                        <div style={{ display: 'flex', gap: '0.5rem' }}>
                            <a href={`${API_BASE}/results_files/combined_target_predictions_all3_human.csv`} download className="btn btn-secondary" style={{ padding: '0.4rem 0.8rem', fontSize: '0.75rem', fontWeight: 'bold', background: '#dcfce7', border: '1px solid #86efac' }}>Download Combined CSV</a>
                        </div>
                    )}
                </div>

                {predictionSummary ? (
                    <div>
                        <div style={{ display: 'flex', gap: '1rem', flexWrap: 'wrap', marginBottom: '1.5rem' }}>
                            <button
                                onClick={() => setPreviewTab('combined')}
                                className={`stat-pill ${previewTab === 'combined' ? 'active' : ''}`}
                                style={{ cursor: 'pointer', border: previewTab === 'combined' ? '2px solid #16a34a' : '1px solid #e2e8f0' }}
                            >
                                <strong>{predictionSummary.combined.count}</strong> Total Targets
                            </button>
                            <button
                                onClick={() => setPreviewTab('swiss')}
                                className={`stat-pill ${previewTab === 'swiss' ? 'active' : ''}`}
                                style={{ background: '#e0f2fe', cursor: 'pointer', border: previewTab === 'swiss' ? '2px solid #0284c7' : '1px solid #bae6fd' }}
                            >
                                <strong>{predictionSummary.swiss.count}</strong> SwissTarget
                                <a href={`${API_BASE}/results_files/swisstargetprediction_results_human.csv`} download style={{ marginLeft: '10px', fontSize: '12px', color: '#0284c7', textDecoration: 'underline' }}>[CSV]</a>
                            </button>
                            <button
                                onClick={() => setPreviewTab('sea')}
                                className={`stat-pill ${previewTab === 'sea' ? 'active' : ''}`}
                                style={{ background: '#fef3c7', cursor: 'pointer', border: previewTab === 'sea' ? '2px solid #d97706' : '1px solid #fde68a' }}
                            >
                                <strong>{predictionSummary.sea.count}</strong> SEA
                                <a href={`${API_BASE}/results_files/sea_results_human.csv`} download style={{ marginLeft: '10px', fontSize: '12px', color: '#d97706', textDecoration: 'underline' }}>[CSV]</a>
                            </button>
                            <button
                                onClick={() => setPreviewTab('ppb3')}
                                className={`stat-pill ${previewTab === 'ppb3' ? 'active' : ''}`}
                                style={{ background: '#fae8ff', cursor: 'pointer', border: previewTab === 'ppb3' ? '2px solid #c026d3' : '1px solid #f5d0fe' }}
                            >
                                <strong>{predictionSummary.ppb3.count}</strong> PPB3
                                <a href={`${API_BASE}/results_files/ppb3_results_human.csv`} download style={{ marginLeft: '10px', fontSize: '12px', color: '#c026d3', textDecoration: 'underline' }}>[CSV]</a>
                            </button>
                        </div>

                        {predictionSummary[previewTab] && predictionSummary[previewTab].preview.length > 0 ? (
                            <div className="table-wrapper" style={{ maxHeight: '350px', overflowX: 'auto' }}>
                                <table style={{ fontSize: '0.8rem', minWidth: (predictionSummary[previewTab].columns?.length * 120 || 800) + 'px' }}>
                                    <thead>
                                        <tr>
                                            {predictionSummary[previewTab].columns?.map(col => (
                                                <th key={col} style={{ whiteSpace: 'nowrap' }}>{col.replace(/_/g, ' ')}</th>
                                            ))}
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {predictionSummary[previewTab].preview.map((row, i) => (
                                            <tr key={i}>
                                                {predictionSummary[previewTab].columns?.map(col => (
                                                    <td key={col} style={{ whiteSpace: 'nowrap' }}>
                                                        {row[col] !== undefined ? row[col].toString() : '-'}
                                                    </td>
                                                ))}
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>
                        ) : (
                            <div style={{ textAlign: 'center', padding: '2rem', opacity: 0.5 }}>No preview rows available for this selection.</div>
                        )}
                    </div>
                ) : <p style={{ color: '#15803d', opacity: 0.6, fontSize: '0.9rem' }}>Analysis results will appear here as an interactive explorer after execution.</p>}
            </div>

            {predictionSummary && (
                <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '2rem' }}>
                    <button className="btn btn-accent" onClick={() => setActiveTab('network')}>Filter and Build Network ➔</button>
                </div>
            )}
        </div>
    )

    const WindowNetwork = () => {

        const downloadFilteredInput = async () => {
            try {
                const timestamp = Date.now()
                const params = {
                    swiss: swissThreshold,
                    ppb3: ppb3Threshold,
                    sea: seaThreshold,
                    sea_pval: seaPval,
                    mode: filterMode,
                    _t: timestamp
                }
                console.log('Downloading with params:', params)

                const res = await axios.get(`${API_BASE}/filter-network-input`, {
                    params,
                    responseType: 'blob'
                })

                console.log('Response received, size:', res.data.size, 'bytes')

                const url = window.URL.createObjectURL(new Blob([res.data]))
                const link = document.createElement('a')
                link.href = url
                const dateStr = new Date().toISOString().slice(0, 19).replace(/:/g, '-')
                link.setAttribute('download', `network_input_filtered_${dateStr}.csv`)
                document.body.appendChild(link)
                link.click()
                link.remove()
                window.URL.revokeObjectURL(url)
                addLog('✅ Network input file downloaded')
            } catch (err) {
                console.error('Download failed:', err)
                addLog('❌ Failed to download network input')
            }
        }

        return (
            <div className="window-card">
                <div className="window-header">
                    <h2>Network Input Preparation</h2>
                    <p>Filter prediction results by database-specific thresholds to prepare network input data.</p>
                </div>

                <div className="control-group" style={{ background: '#fafafa', border: '1px solid #e0e0e0', marginBottom: '2rem' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
                        <h3 style={{ color: '#374151', margin: 0, fontSize: '1.1rem' }}>Threshold Filters</h3>
                        <div style={{ display: 'flex', gap: '0.3rem', alignItems: 'center', background: '#f9fafb', padding: '0.2rem', borderRadius: '4px', border: '1px solid #e5e7eb' }}>
                            <button
                                style={{
                                    padding: '0.3rem 0.8rem',
                                    fontSize: '0.75rem',
                                    background: filterMode === 'OR' ? '#3b82f6' : 'transparent',
                                    color: filterMode === 'OR' ? 'white' : '#6b7280',
                                    border: 'none',
                                    borderRadius: '3px',
                                    cursor: 'pointer',
                                    fontWeight: '600'
                                }}
                                onClick={() => setFilterMode('OR')}
                            >OR</button>
                            <button
                                style={{
                                    padding: '0.3rem 0.8rem',
                                    fontSize: '0.75rem',
                                    background: filterMode === 'AND' ? '#3b82f6' : 'transparent',
                                    color: filterMode === 'AND' ? 'white' : '#6b7280',
                                    border: 'none',
                                    borderRadius: '3px',
                                    cursor: 'pointer',
                                    fontWeight: '600'
                                }}
                                onClick={() => setFilterMode('AND')}
                            >AND</button>
                        </div>
                    </div>

                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1.5rem' }}>
                        <div className="control-group" style={{ background: 'white', border: '1px solid #d1d5db' }}>
                            <label style={{ color: '#374151', fontWeight: '600', fontSize: '0.9rem' }}>
                                SwissTarget Probability ≥ <span style={{ color: '#1f2937' }}>{(swissThreshold || 0).toFixed(3)}</span>
                            </label>
                            <div style={{ fontSize: '0.75rem', color: '#6b7280', marginBottom: '0.5rem' }}>
                                Range: 0 to {(maxValues?.swiss || 1).toFixed(3)}
                            </div>
                            <input
                                type="range"
                                min="0"
                                max={maxValues?.swiss || 1}
                                step="0.001"
                                value={swissThreshold || 0}
                                onChange={(e) => setSwissThreshold(parseFloat(e.target.value))}
                            />
                        </div>

                        <div className="control-group" style={{ background: 'white', border: '1px solid #d1d5db' }}>
                            <label style={{ color: '#374151', fontWeight: '600', fontSize: '0.9rem' }}>
                                PPB3 Probability ≥ <span style={{ color: '#1f2937' }}>{(ppb3Threshold || 0).toFixed(3)}</span>
                            </label>
                            <div style={{ fontSize: '0.75rem', color: '#6b7280', marginBottom: '0.5rem' }}>
                                Range: 0 to {(maxValues?.ppb3 || 1).toFixed(3)}
                            </div>
                            <input
                                type="range"
                                min="0"
                                max={maxValues?.ppb3 || 1}
                                step="0.001"
                                value={ppb3Threshold || 0}
                                onChange={(e) => setPpb3Threshold(parseFloat(e.target.value))}
                            />
                        </div>

                        <div className="control-group" style={{ background: 'white', border: '1px solid #d1d5db' }}>
                            <label style={{ color: '#374151', fontWeight: '600', fontSize: '0.9rem' }}>
                                SEA MaxTc ≥ <span style={{ color: '#1f2937' }}>{(seaThreshold || 0).toFixed(3)}</span>
                            </label>
                            <div style={{ fontSize: '0.75rem', color: '#6b7280', marginBottom: '0.5rem' }}>
                                Range: 0 to {(maxValues?.sea || 1).toFixed(3)}
                            </div>
                            <input
                                type="range"
                                min="0"
                                max={maxValues?.sea || 1}
                                step="0.001"
                                value={seaThreshold || 0}
                                onChange={(e) => setSeaThreshold(parseFloat(e.target.value))}
                            />
                        </div>

                        <div className="control-group" style={{ background: 'white', border: '1px solid #d1d5db' }}>
                            <label style={{ color: '#374151', fontWeight: '600', fontSize: '0.9rem' }}>
                                SEA P-Value ≤ <span style={{ color: '#1f2937' }}>{(seaPval || 1).toExponential(2)}</span>
                            </label>
                            <div style={{ fontSize: '0.75rem', color: '#6b7280', marginBottom: '0.5rem' }}>
                                Range: 0 to {(maxValues?.seaPval || 1).toExponential(2)}
                            </div>
                            <input
                                type="range"
                                min="0"
                                max={maxValues?.seaPval || 1}
                                step={(maxValues?.seaPval || 1) / 1000}
                                value={seaPval || 1}
                                onChange={(e) => setSeaPval(parseFloat(e.target.value))}
                            />
                        </div>
                    </div>

                    <div style={{ marginTop: '1.5rem', paddingTop: '1rem', borderTop: '1px solid #e5e7eb' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                                <button
                                    className="btn btn-primary"
                                    onClick={downloadFilteredInput}
                                    style={{ padding: '0.8rem 2rem' }}
                                >
                                    💾 Download Filtered Input
                                </button>
                                <label className="btn btn-secondary" style={{ padding: '0.8rem 1.5rem', cursor: 'pointer', border: '1px dashed #cbd5e1' }}>
                                    📂 Upload Custom Input
                                    <input type="file" hidden onChange={handleNetworkUpload} accept=".csv" />
                                </label>
                                <span style={{
                                    padding: '0.5rem 1rem',
                                    background: filteredCount > 0 ? '#d1fae5' : '#f3f4f6',
                                    border: `1px solid ${filteredCount > 0 ? '#10b981' : '#d1d5db'}`,
                                    borderRadius: '6px',
                                    fontSize: '0.9rem',
                                    fontWeight: '600',
                                    color: filteredCount > 0 ? '#065f46' : '#6b7280'
                                }}>
                                    {filteredCount} rows
                                </span>
                            </div>
                            <div style={{ fontSize: '0.85rem', color: '#6b7280', textAlign: 'right' }}>
                                <div style={{ fontWeight: '600', marginBottom: '0.25rem' }}>
                                    Filter Mode: {filterMode}
                                </div>
                                <div style={{ fontSize: '0.75rem' }}>
                                    {filterMode === 'OR' ? 'ANY active threshold' : 'ALL active thresholds'}
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '2rem' }}>
                    <button className="btn btn-accent" onClick={() => setActiveTab('network-viz')}>Next: Network Visualization ➔</button>
                </div>
            </div>
        )
    }

    const WindowNetworkViz = () => {
        const [isDragging, setIsDragging] = useState(false)

        const handleDragEnter = (e) => {
            e.preventDefault()
            e.stopPropagation()
            setIsDragging(true)
        }

        const handleDragLeave = (e) => {
            e.preventDefault()
            e.stopPropagation()
            setIsDragging(false)
        }

        const handleDrop = async (e) => {
            e.preventDefault()
            e.stopPropagation()
            setIsDragging(false)
            await handleNetworkUpload(e)
        }

        return (
            <div className="window-card">
                <div className="window-header">
                    <h2>Network Visualization</h2>
                    <p>Configure visual parameters and generate the network plot.</p>
                </div>

                <h3>Visual Styling</h3>
                <div className="controls-grid">
                    <div className="control-group"><label>Labels Size</label><input type="number" value={fontSize} onChange={(e) => setFontSize(parseInt(e.target.value))} /></div>
                    <div className="control-group">
                        <label>Layout</label>
                        <select value={layoutType} onChange={(e) => setLayoutType(e.target.value)}>
                            <option value="kk">Kamada-Kawai</option><option value="fr">Fruchterman-Reingold</option>
                        </select>
                    </div>
                    <div className="control-group"><label>DPI</label><input type="number" value={dpi} onChange={(e) => setDpi(parseInt(e.target.value))} /></div>
                </div>
                <div style={{ display: 'flex', justifyContent: 'center', margin: '2rem 0', gap: '1rem' }}>
                    <label
                        className="btn btn-secondary"
                        style={{
                            padding: '1rem 2rem',
                            cursor: 'pointer',
                            border: isDragging ? '2px dashed #3b82f6' : '1px dashed #cbd5e1',
                            background: isDragging ? '#eff6ff' : 'transparent',
                            display: 'flex',
                            alignItems: 'center',
                            gap: '0.5rem',
                            transition: 'all 0.2s ease'
                        }}
                        onDragOver={handleDragEnter}
                        onDragEnter={handleDragEnter}
                        onDragLeave={handleDragLeave}
                        onDrop={handleDrop}
                    >
                        {isDragging ? '📂 Drop File Here!' : (filterStats.customFile ? `📄 Using: ${filterStats.customFile}` : '📂 Upload Input (Drag & Drop)')}
                        <input type="file" hidden onChange={handleNetworkUpload} accept=".csv" />
                    </label>

                    {filterStats.customFile && (
                        <button
                            className="btn btn-secondary"
                            onClick={async () => {
                                try {
                                    await axios.post(`${API_BASE}/clear-network-input`)
                                    setFilterStats(prev => ({ ...prev, customFile: null }))
                                    addLog("ℹ️ Reverted to system-generated predictions")
                                } catch (e) { console.error(e) }
                            }}
                            style={{ padding: '1rem', borderColor: '#ef4444', color: '#ef4444' }}
                        >
                            ❌ Reset
                        </button>
                    )}
                    <button
                        className="btn btn-primary"
                        style={{ padding: '1rem 3rem' }}
                        onClick={() => runStage('Network Generation', 'reanalyze', {
                            stage: 'network',
                            fontSize,
                            dpi,
                            layout: layoutType,
                            swiss: swissThreshold,
                            ppb3: ppb3Threshold,
                            sea: seaThreshold,
                            sea_pval: seaPval,
                            fontStyle
                        })}
                        disabled={isRunning}
                    >
                        {results.filter(r => r.category === 'tcm_network').length > 0 ? '🔄 Update Visualization' : '🕸 Visualize Network'}
                    </button>
                </div>

                {results.filter(r => r.category === 'tcm_network').length > 0 ? (
                    renderResultsByCategory('tcm_network')
                ) : (
                    <div style={{ textAlign: 'center', padding: '3rem', color: '#6b7280', background: '#f9fafb', borderRadius: '8px', border: '1px solid #e5e7eb' }}>
                        <p style={{ fontSize: '1.1rem', marginBottom: '0.5rem' }}>No network visualization yet</p>
                        <p style={{ fontSize: '0.9rem' }}>Click "Visualize Network" above to generate the plot</p>
                    </div>
                )}

                <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '2rem' }}>
                    <button className="btn btn-accent" onClick={() => setActiveTab('ppi')}>Next: PPI Analysis ➔</button>
                </div>
            </div>
        )
    }

    const WindowPPI = () => (
        <div className="window-card">
            <div className="window-header"><h2>PPI Network Builder</h2><p>STRING module analysis for protein associations.</p></div>
            <div className="controls-grid">
                <div className="control-group"><label>Degree Filter <span>{ppiDegreeFilter}</span></label><input type="range" min="1" max="15" value={ppiDegreeFilter} onChange={(e) => setPpiDegreeFilter(parseInt(e.target.value))} /></div>
                <div className="control-group"><label>Confidence <span>{ppiConfidence.toFixed(2)}</span></label><input type="range" min="0" max="1" step="0.01" value={ppiConfidence} onChange={(e) => setPpiConfidence(parseFloat(e.target.value))} /></div>
            </div>
            <div style={{ display: 'flex', justifyContent: 'center', margin: '2rem 0' }}><button className="btn btn-primary" onClick={() => runStage('PPI Analysis', 'reanalyze', { stage: 'ppi', ppiFilter: ppiDegreeFilter, sea_tc: ppiConfidence, fontSize, fontStyle, dpi, layout: layoutType })} disabled={isRunning}>🔗 Build PPI</button></div>

            {results.filter(r => r.category === 'ppi').length > 0 ? (
                renderResultsByCategory('ppi')
            ) : (
                <div style={{ textAlign: 'center', padding: '3rem', color: '#6b7280', background: '#f9fafb', borderRadius: '8px', border: '1px solid #e5e7eb', margin: '2rem 0' }}>
                    <p style={{ fontSize: '1.1rem', marginBottom: '0.5rem' }}>No PPI network yet</p>
                    <p style={{ fontSize: '0.9rem' }}>Click "Build PPI" above to generate the network</p>
                </div>
            )}

            <div style={{ display: 'flex', justifyContent: 'flex-end' }}><button className="btn btn-accent" onClick={() => setActiveTab('enrichment')}>Next: Enrichment ➔</button></div>
        </div>
    )

    const WindowEnrichment = () => (
        <div className="window-card">
            <div className="window-header"><h2>Functional Enrichment</h2><p>KEGG pathways and Gene Ontology analysis.</p></div>
            <div className="controls-center" style={{ textAlign: 'center', marginBottom: '2rem' }}><label>Top N Results</label> <input type="number" value={topNPathways} onChange={(e) => setTopNPathways(e.target.value)} style={{ maxWidth: '100px' }} /></div>
            <div style={{ display: 'flex', justifyContent: 'center', margin: '2rem 0' }}>
                <button
                    className="btn btn-primary"
                    onClick={() => runStage('Enrichment', 'reanalyze', {
                        stage: 'enrichment',
                        topN: topNPathways,
                        fontSize, fontStyle, dpi, layout: layoutType
                    })}
                    disabled={isRunning}
                >
                    📊 Run Enrichment
                </button>
            </div>
            <div className="tabs-header">
                {['kegg_enrichment', 'go_bp'].map(cat => (
                    <button
                        key={cat}
                        className={`tab-btn ${enrichmentTab === cat ? 'active' : ''}`}
                        onClick={() => setEnrichmentTab(cat)}
                    >
                        {cat === 'kegg_enrichment' ? 'KEGG Pathways' : 'GO Biological Process'}
                    </button>
                ))}
            </div>
            {renderResultsByCategory(enrichmentTab)}
            <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '2rem' }}><button className="btn btn-accent" onClick={() => setActiveTab('disease')}>Next: Disease Overlap ➔</button></div>
        </div>
    )

    const WindowDisease = () => (
        <div className="window-card">
            <div className="window-header"><h2>Disease Overlap</h2><p>Mapping phytochemical targets to specific EFO IDs.</p></div>
            <div className="controls-center" style={{ textAlign: 'center', marginBottom: '2rem' }}><label>EFO ID / Disease</label> <input type="text" value={diseaseInput} onChange={(e) => setDiseaseInput(e.target.value)} placeholder="EFO_0000305" style={{ maxWidth: '300px' }} /></div>
            <div style={{ display: 'flex', justifyContent: 'center', margin: '2rem 0' }}>
                <button
                    className="btn btn-primary"
                    onClick={() => runStage('Disease Analysis', 'reanalyze', {
                        stage: 'disease',
                        diseaseInput,
                        fontSize, fontStyle, dpi, layout: layoutType
                    })}
                    disabled={isRunning}
                >
                    🧬 Run Map
                </button>
            </div>
            {renderResultsByCategory('validation')}
        </div>
    )

    const renderResultsByCategory = (category) => {
        const rawFiles = results.filter(f => f.category === category)
        if (rawFiles.length === 0) return null

        // Group files by base name
        const groups = {}
        rawFiles.forEach(f => {
            const base = f.name.replace(/\.(png|svg|tiff|tif|pdf)$/i, '')
            if (!groups[base]) groups[base] = { name: base, formats: {} }
            const ext = f.name.split('.').pop().toLowerCase()
            groups[base].formats[ext] = f
        })

        const groupList = Object.values(groups)

        const downloadAll = () => {
            rawFiles.forEach((file, index) => {
                setTimeout(() => {
                    const link = document.createElement('a')
                    link.href = file.url
                    link.download = file.name
                    document.body.appendChild(link)
                    link.click()
                    document.body.removeChild(link)
                }, index * 300)
            })
            addLog(`📥 Downloading all ${rawFiles.length} files in ${category}`)
        }

        return (
            <div className="preview-grid" style={{ display: 'grid', gridTemplateColumns: '1fr 340px', gap: '2.5rem' }}>
                <div className="plot-preview">
                    {activePlot ? (
                        <>
                            <div style={{ display: 'flex', justifyContent: 'space-between', width: '100%', marginBottom: '1.5rem', alignItems: 'center' }}>
                                <div>
                                    <h3 style={{ margin: 0, fontSize: '1.2rem', color: '#1e293b' }}>{activePlot.name.replace(/\.[^/.]+$/, "")}</h3>
                                    <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.25rem' }}>
                                        <span className="badge badge-indigo" style={{ fontSize: '0.6rem' }}>{activePlot.name.split('.').pop().toUpperCase()}</span>
                                        <span style={{ fontSize: '0.7rem', color: '#64748b' }}>Resolution: {activePlot.name.toLowerCase().endsWith('.png') ? `High-DPI (${dpi} DPI)` : 'Vector'}</span>
                                    </div>
                                </div>
                                <div style={{ display: 'flex', gap: '0.75rem', alignItems: 'center' }}>
                                    <div style={{ marginRight: '1rem', textAlign: 'right' }}>
                                        <span style={{ fontSize: '0.65rem', color: '#94a3b8', display: 'block' }}>Active Filters (Current):</span>
                                        <span style={{ fontSize: '0.7rem', fontWeight: 600, color: '#64748b' }}>S:{swissThreshold} P:{ppb3Threshold} Tc:{seaThreshold}</span>
                                    </div>
                                    <button onClick={() => setZoomedImage(`${activePlot.url}?t=${new Date().getTime()}`)} className="btn btn-secondary" style={{ padding: '0.5rem 1rem' }}>⛶ Full Screen</button>
                                    <a href={`${activePlot.url}?t=${new Date().getTime()}`} download className="btn btn-secondary" style={{ padding: '0.5rem 1.25rem' }}>💾 Download</a>
                                    <button onClick={downloadAll} className="btn btn-primary" style={{ padding: '0.5rem 1.25rem' }}>📦 Download All</button>
                                </div>
                            </div>

                            {(activePlot.name.toLowerCase().endsWith('.png') || activePlot.name.toLowerCase().endsWith('.svg')) ? (
                                <div className="preview-image-container" style={{ width: '100%', position: 'relative' }}>
                                    <img
                                        src={`${activePlot.url}?t=${new Date().getTime()}`}
                                        alt="Preview"
                                        key={activePlot.url}
                                        onClick={() => setZoomedImage(`${activePlot.url}?t=${new Date().getTime()}`)}
                                        style={{ width: '100%', display: 'block' }}
                                    />
                                    <div style={{ position: 'absolute', bottom: '1rem', right: '1rem', background: 'rgba(255,255,255,0.8)', padding: '0.5rem', borderRadius: '50%', cursor: 'pointer', boxShadow: '0 2px 10px rgba(0,0,0,0.1)' }} onClick={() => setZoomedImage(`${activePlot.url}?t=${new Date().getTime()}`)}>🔍</div>
                                </div>
                            ) : (
                                <div style={{ padding: '6rem 2rem', textAlign: 'center', background: '#f8fafc', borderRadius: '1.5rem', width: '100%', border: '2px dashed #cbd5e1' }}>
                                    <span style={{ fontSize: '4rem' }}>📄</span>
                                    <p style={{ fontWeight: 700, fontSize: '1.2rem', marginTop: '1.5rem', color: '#334155' }}>Preview Unavailable for {activePlot.name.split('.').pop().toUpperCase()}</p>
                                    <p style={{ color: '#64748b', marginBottom: '2rem' }}>This high-resolution format is best viewed in a local image editor.</p>
                                    <a href={activePlot.url} download className="btn btn-primary" style={{ padding: '0.75rem 2rem' }}>💾 Download File</a>
                                </div>
                            )}
                        </>
                    ) : <div style={{ padding: '8rem', color: '#94a3b8', textAlign: 'center' }}>
                        <span style={{ fontSize: '3rem', opacity: 0.3 }}>🖼️</span>
                        <p style={{ marginTop: '1rem' }}>Select a result from the gallery to preview</p>
                    </div>}
                </div>

                <div className="gallery-sidebar">
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
                        <h4 style={{ fontSize: '0.75rem', color: '#64748b', fontWeight: 800, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Session Results</h4>
                        <span style={{ fontSize: '0.7rem', color: '#94a3b8' }}>{groupList.length} Items</span>
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
                        {groupList.map(group => {
                            // Find PNG for thumbnail if it exists, otherwise use SVG
                            const thumbFile = group.formats.png || group.formats.svg || Object.values(group.formats)[0]
                            const isActive = activePlot && activePlot.name.startsWith(group.name)

                            return (
                                <div key={group.name} className={`thumb-card ${isActive ? 'active' : ''}`} onClick={() => setActivePlot(group.formats.png || thumbFile)}>
                                    <div style={{ height: '120px', background: '#f1f5f9', borderRadius: '0.75rem', overflow: 'hidden', display: 'flex', alignItems: 'center', justifyContent: 'center', border: '1px solid #e2e8f0' }}>
                                        {(group.formats.png || group.formats.svg) ? (
                                            <img src={`${(group.formats.png || group.formats.svg).url}?t=${new Date().getTime()}`} alt={group.name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                                        ) : <span style={{ fontSize: '2rem' }}>📄</span>}
                                    </div>
                                    <div style={{ padding: '0.5rem 0.25rem' }}>
                                        <span style={{ fontWeight: 700, fontSize: '0.9rem', color: '#1e293b', display: 'block', marginBottom: '0.5rem', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{group.name}</span>
                                        <div className="format-badges" style={{ display: 'flex', gap: '0.4rem' }}>
                                            {Object.keys(group.formats).map(ext => (
                                                <span
                                                    key={ext}
                                                    className={`format-badge ${activePlot?.name === group.formats[ext].name ? 'active' : ''}`}
                                                    onClick={(e) => { e.stopPropagation(); setActivePlot(group.formats[ext]); }}
                                                    style={{ cursor: 'pointer' }}
                                                >
                                                    {ext}
                                                </span>
                                            ))}
                                        </div>
                                    </div>
                                </div>
                            )
                        })}
                    </div>
                </div>
            </div>
        )
    }

    return (
        <div className="dashboard">
            <header>
                <h1>🧬 Network Pharmacology <span className="badge badge-indigo">PRO</span></h1>
                <div style={{ display: 'flex', gap: '1rem', alignItems: 'center' }}>
                    {isRunning && <span className="loading-dots" style={{ color: '#4f46e5', fontSize: '0.8rem' }}>Pipeline Active...</span>}
                    <div className="badge badge-pink" style={{ cursor: 'pointer' }} onClick={() => setShowTerminal(!showTerminal)}>Monitor {showTerminal ? '▼' : '▲'}</div>
                </div>
            </header>
            <div className="main-layout">
                <aside className="sidebar">
                    {NAV_ITEMS.map(item => (
                        <button key={item.id} className={`nav-item ${activeTab === item.id ? 'active' : ''}`} onClick={() => setActiveTab(item.id)}>
                            <span className="nav-icon">{item.icon}</span>{item.label}
                        </button>
                    ))}
                </aside>
                <main className="window-container">
                    {activeTab === 'data' && <WindowData />}
                    {activeTab === 'prediction' && <WindowPrediction />}
                    {activeTab === 'network' && <WindowNetwork />}
                    {activeTab === 'network-viz' && <WindowNetworkViz />}
                    {activeTab === 'ppi' && <WindowPPI />}
                    {activeTab === 'enrichment' && <WindowEnrichment />}
                    {activeTab === 'disease' && <WindowDisease />}
                </main>
            </div>

            {showTerminal && (
                <div style={{
                    position: 'fixed',
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: '250px',
                    background: '#0f172a',
                    borderTop: '2px solid #334155',
                    zIndex: 1000,
                    display: 'flex',
                    flexDirection: 'column'
                }}>
                    <div style={{
                        padding: '0.5rem 1rem',
                        background: '#1e293b',
                        borderBottom: '1px solid #334155',
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center'
                    }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                            <div className={`status-dot ${isRunning ? 'active' : ''}`} />
                            <span style={{ color: '#e2e8f0', fontWeight: '600', fontSize: '0.85rem' }}>ACTIVITY MONITOR</span>
                            <span style={{ fontSize: '0.7rem', opacity: 0.6, color: '#94a3b8' }}>{activeTab.toUpperCase()}</span>
                        </div>
                        <div style={{ display: 'flex', gap: '1rem', alignItems: 'center' }}>
                            <span
                                style={{ cursor: isRunning ? 'not-allowed' : 'pointer', opacity: isRunning ? 0.3 : 1, color: '#94a3b8', fontSize: '0.85rem' }}
                                onClick={clearLogs}
                            >Clear</span>
                            <span
                                style={{ cursor: 'pointer', color: '#94a3b8', fontSize: '0.85rem' }}
                                onClick={() => setShowTerminal(false)}
                            >✖ Close</span>
                        </div>
                    </div>
                    <div style={{
                        flex: 1,
                        overflow: 'auto',
                        padding: '1rem',
                        fontFamily: 'monospace',
                        fontSize: '12px',
                        color: '#e2e8f0',
                        whiteSpace: 'pre-wrap'
                    }}>
                        {logs || 'Waiting for process to start...'}
                        <div ref={terminalEndRef} />
                    </div>
                    {isRunning && (
                        <div style={{ padding: '0.5rem', background: '#020617', borderTop: '1px solid #1e293b', textAlign: 'center' }}>
                            <button className="btn btn-secondary" style={{ fontSize: '10px', padding: '4px 12px', color: '#f87171', borderColor: '#450a0a' }} onClick={stopProcess}>STOP PROCESS</button>
                        </div>
                    )}
                </div>
            )}
            {zoomedImage && (
                <div className="zoom-overlay" onClick={() => setZoomedImage(null)}>
                    <img
                        src={zoomedImage}
                        alt="Zoomed"
                        onClick={(e) => e.stopPropagation()}
                    />
                    <div style={{ position: 'absolute', top: '2rem', right: '2rem', color: 'white', fontSize: '2rem', cursor: 'pointer' }}>×</div>
                </div>
            )}
        </div>
    )
}

export default App
