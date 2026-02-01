import { useState, useRef, useEffect } from 'react'
import axios from 'axios'

const API_BASE = 'http://localhost:8000'

function App() {
    const [file, setFile] = useState(null)
    const [uploadedFilename, setUploadedFilename] = useState('')
    const [logs, setLogs] = useState('')
    const [results, setResults] = useState([])
    const [isRunning, setIsRunning] = useState(false)
    const [progress, setProgress] = useState(0)
    const [progressMessage, setProgressMessage] = useState('')
    const [message, setMessage] = useState({ type: '', text: '' })
    const [openCategories, setOpenCategories] = useState({ image: true, csv: true, cytoscape: true })
    const [activeTab, setActiveTab] = useState('go_bp')

    // Settings
    const [fontSize, setFontSize] = useState(14)
    const [fontStyle, setFontStyle] = useState('bold')
    const [dpi, setDpi] = useState(600)
    const [minProbability, setMinProbability] = useState(0.5) // Default 0.5

    const eventSourceRef = useRef(null)
    const resultsRef = useRef(null)

    const toggleCategory = (cat) => {
        setOpenCategories(prev => ({ ...prev, [cat]: !prev[cat] }))
    }

    const handleFileChange = (e) => {
        setFile(e.target.files[0])
        setMessage({ type: '', text: '' })
    }

    const handleUpload = async () => {
        if (!file) {
            setMessage({ type: 'error', text: 'Please select a file first' })
            return
        }

        const formData = new FormData()
        formData.append('file', file)

        try {
            const response = await axios.post(`${API_BASE}/upload`, formData, {
                headers: { 'Content-Type': 'multipart/form-data' }
            })
            setUploadedFilename(response.data.filename)
            setMessage({ type: 'success', text: `File uploaded: ${response.data.filename}` })
        } catch (error) {
            setMessage({ type: 'error', text: `Upload failed: ${error.message}` })
        }
    }

    const fetchResults = async () => {
        try {
            const response = await axios.get(`${API_BASE}/results`)
            setResults(response.data.files)
            if (response.data.files.length > 0) {
                setTimeout(() => {
                    resultsRef.current?.scrollIntoView({ behavior: 'smooth' })
                }, 500)
            }
        } catch (error) {
            console.error('Failed to fetch results:', error)
        }
    }

    const handleRunPipeline = () => {
        if (!uploadedFilename) {
            setMessage({ type: 'error', text: 'Please upload a file first' })
            return
        }

        setIsRunning(true)
        setProgress(0)
        setProgressMessage('Connecting to server...')
        setLogs('Connecting to pipeline...\n')
        setResults([])
        setMessage({ type: '', text: '' })

        if (eventSourceRef.current) {
            eventSourceRef.current.close()
        }

        if (eventSourceRef.current) {
            eventSourceRef.current.close()
        }

        const params = new URLSearchParams({ fontSize, fontStyle, dpi, minProbability })
        const eventSource = new EventSource(`${API_BASE}/run-stream?${params.toString()}`)
        eventSourceRef.current = eventSource

        eventSource.onmessage = (event) => {
            const data = event.data

            if (data === 'DONE') {
                eventSource.close()
                setIsRunning(false)
                setProgress(100)
                setProgressMessage('Completed successfully')

                if (logs.includes('ERROR')) {
                    setMessage({ type: 'error', text: 'Pipeline failed - check logs for details' })
                } else {
                    setMessage({ type: 'success', text: 'Pipeline completed successfully!' })
                    fetchResults()
                }
                return
            }

            // Parse progress if present
            if (data.startsWith('PROGRESS:')) {
                const parts = data.split(':')
                const pct = parseInt(parts[1])
                const msg = parts.slice(2).join(':')
                setProgress(pct)
                setProgressMessage(msg)
            } else {
                setLogs(prev => prev + data)
            }
        }

        eventSource.onerror = (error) => {
            console.error('EventSource error:', error)
            eventSource.close()
            setIsRunning(false)
            setMessage({ type: 'error', text: 'Connection to server lost' })
        }
    }

    const handleReset = async () => {
        try {
            await axios.post(`${API_BASE}/reset`)
            setIsRunning(false)
            setProgress(0)
            setMessage({ type: 'success', text: 'Backend state reset successfully' })
        } catch (error) {
            setMessage({ type: 'error', text: 'Reset failed' })
        }
    }

    const downloadAll = () => {
        window.open(`${API_BASE}/download-all`, '_blank')
    }

    // Specialized Extraction
    const integratedNetwork = results.find(f => f.category === 'integrated_network')
    const validationVenn = results.find(f => f.category === 'validation')
    const goBp = results.find(f => f.category === 'go_bp')
    const goMf = results.find(f => f.category === 'go_mf')
    const goCc = results.find(f => f.category === 'go_cc')
    const doEnrich = results.find(f => f.category === 'do')
    const keggLollipop = results.find(f => f.category === 'kegg_enrichment')
    const pathwayMaps = results.filter(f => f.category === 'pathway_map').slice(0, 5)
    const sankeyPlot = results.find(f => f.category === 'sankey')
    const alluvialPlot = results.find(f => f.category === 'alluvial')
    const tcmPlot = results.find(f => f.category === 'tcm_network')
    const ppiPlot = results.find(f => f.category === 'ppi')
    const degreePlot = results.find(f => f.category === 'degree')

    // Cytoscape Files
    const cytoscapeFiles = results.filter(f => f.url.includes('cytoscape_files'))

    const groupedResults = {
        image: results.filter(f => f.type === 'image'),
        csv: results.filter(f => f.type === 'csv' && !f.url.includes('cytoscape_files')), // Exclude cytoscape from general CSV
        cytoscape: cytoscapeFiles
    }

    const categoryLabels = {
        image: '🖼️ All Plots & Graphs',
        csv: '📊 Data Tables (CSV Preview)',
        cytoscape: '🕸️ Cytoscape Ready Files'
    }

    const renderTabContent = () => {
        switch (activeTab) {
            case 'go_bp': return goBp ? <img src={goBp.url} className="enrichment-chart" alt="GO BP" /> : <p>BP Analysis chart not available</p>;
            case 'go_mf': return goMf ? <img src={goMf.url} className="enrichment-chart" alt="GO MF" /> : <p>MF Analysis chart not available</p>;
            case 'go_cc': return goCc ? <img src={goCc.url} className="enrichment-chart" alt="GO CC" /> : <p>CC Analysis chart not available</p>;
            case 'do': return doEnrich ? <img src={doEnrich.url} className="enrichment-chart" alt="DO" /> : <p>DO Analysis chart not available</p>;
            case 'kegg': return keggLollipop ? <img src={keggLollipop.url} className="enrichment-chart" alt="KEGG" /> : <p>KEGG chart not available</p>;
            default: return null;
        }
    }

    const CsvPreview = ({ file }) => {
        const [showRows, setShowRows] = useState(false)
        if (!file.csv_meta) return null;

        return (
            <div className="csv-preview-container">
                <div className="csv-meta-info" onClick={() => setShowRows(!showRows)} style={{ cursor: 'pointer' }}>
                    🔢 {file.csv_meta.rows} rows, {file.csv_meta.cols} columns | 🏷️ {file.csv_meta.headers.join(', ')}
                    <span style={{ float: 'right' }}>{showRows ? '▲ Hide Preview' : '▼ Show Preview'}</span>
                </div>
                {showRows && (
                    <div className="csv-scroll-wrapper">
                        <table className="preview-table">
                            <thead>
                                <tr>
                                    {file.csv_meta.headers.map((h, i) => <th key={i}>{h}</th>)}
                                </tr>
                            </thead>
                            <tbody>
                                {file.csv_meta.preview.map((row, i) => (
                                    <tr key={i}>
                                        {row.map((cell, j) => <td key={j}>{cell}</td>)}
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                )}
            </div>
        )
    }

    const getAltfomats = (file) => {
        if (file.type !== 'image') return null;
        const base = file.url.substring(0, file.url.lastIndexOf('.'))
        return (
            <>
                <a href={`${base}.tiff`} className="download-btn tif" target="_blank" rel="noreferrer" download>TIF</a>
                <a href={`${base}.svg`} className="download-btn svg" target="_blank" rel="noreferrer" download>SVG</a>
            </>
        )
    }

    return (
        <div className="container">
            <h1>🧬 Bioinformatics Analysis Dashboard</h1>

            <div className="upload-section">
                <h2>1. Upload Compound Data</h2>
                <input type="file" accept=".csv,.txt" onChange={handleFileChange} disabled={isRunning} />
                <button onClick={handleUpload} disabled={isRunning}>Upload</button>
            </div>

            <div className="settings-section">
                <h2>⚙️ Analysis Settings</h2>
                <div className="settings-grid">
                    <div className="settings-group">
                        <label>Font Size</label>
                        <input type="number" value={fontSize} onChange={(e) => setFontSize(e.target.value)} disabled={isRunning} />
                    </div>
                    <div className="settings-group">
                        <label>Font Style</label>
                        <select value={fontStyle} onChange={(e) => setFontStyle(e.target.value)} disabled={isRunning}>
                            <option value="bold">Bold</option>
                            <option value="italic">Italic</option>
                            <option value="plain">Plain</option>
                        </select>
                    </div>
                    <div className="settings-group">
                        <label>Resolution (DPI)</label>
                        <select value={dpi} onChange={(e) => setDpi(e.target.value)} disabled={isRunning}>
                            <option value="72">72 (Web)</option>
                            <option value="150">150 (Draft)</option>
                            <option value="300">300 (Publication)</option>
                            <option value="600">600 (High Detail)</option>
                        </select>
                    </div>
                    <div className="settings-group">
                        <label>Min. Confidence (0.1 - 1.0)</label>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                            <input
                                type="range"
                                min="0.1"
                                max="1.0"
                                step="0.05"
                                value={minProbability}
                                onChange={(e) => setMinProbability(parseFloat(e.target.value))}
                                disabled={isRunning}
                                style={{ flex: 1 }}
                            />
                            <span>{minProbability}</span>
                        </div>
                    </div>
                </div>
            </div>

            <div className="run-section">
                <h2>2. Process Pipeline</h2>
                {isRunning && (
                    <div className="progress-container">
                        <div className="progress-fill" style={{ width: `${progress}%` }}>
                            {progress}%
                        </div>
                        <div className="progress-text">Step: {progressMessage}</div>
                    </div>
                )}
                <div className="button-group">
                    <button onClick={handleRunPipeline} disabled={isRunning || !uploadedFilename} className="run-button">
                        {isRunning ? 'Pipeline Running...' : 'Run Full Pipeline'}
                    </button>
                    {!isRunning && (
                        <button onClick={handleReset} className="reset-button">Reset System</button>
                    )}
                </div>
            </div>

            {message.text && (
                <div className={`message ${message.type}`}>
                    {message.text}
                </div>
            )}

            {results.length > 0 && (
                <div className="results-section" ref={resultsRef}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
                        <h2>📊 Final Analysis Results</h2>
                        <button className="download-all-btn" onClick={downloadAll}>📦 Download All (ZIP)</button>
                    </div>

                    {/* SECTION 1: VALIDATION */}
                    {validationVenn && (
                        <div className="validation-grid">
                            <div className="validation-card">
                                <h3>⚖️ Step 1: Disease-Target Overlap</h3>
                                <div className="section-overview">
                                    <strong>Method:</strong> Specifically visualizes the intersection (Venn diagram logic plotted as a network) between the targets predicted by your ingredients and the targets known to cause the disease from the EFO ID.
                                </div>
                                <img src={validationVenn.url} className="validation-img" alt="Venn Diagram" onClick={() => window.open(validationVenn.url, '_blank')} />
                            </div>
                            <div className="validation-card">
                                <h3>📋 Strategic Highlights</h3>
                                <p style={{ marginTop: '10px' }}>Identifying core targets responsible for the medicinal effect ensures the subsequent analysis is focused on therapeutic relevance.</p>
                                <div style={{ marginTop: '15px' }}>
                                    <button className="view-btn" onClick={() => setActiveTab('do')}>Explore Disease Ontology</button>
                                </div>
                            </div>
                        </div>
                    )}

                    {/* SECTION 2: INTEGRATED NETWORKS */}
                    {integratedNetwork && (
                        <div className="network-view-section">
                            <h3>🕸️ Step 2: Integrated NP-Disease Network</h3>
                            <div className="section-overview">
                                <strong>Method:</strong> Visualizes the structural relationships between Herbs, Ingredients, Targets, and Diseases using igraph and ggraph. Nodes are colored by type (Herb, Molecule, Common Target), and layout algorithms show clusters.
                            </div>
                            <div className="large-network-container">
                                <img src={integratedNetwork.url} className="large-network-img" alt="Integrated Network" onClick={() => window.open(integratedNetwork.url, '_blank')} title="Click to view full image" />
                            </div>
                        </div>
                    )}

                    {/* SECTION 3: STRUCTURAL INTERACTIONS */}
                    {(sankeyPlot || alluvialPlot || tcmPlot || ppiPlot || degreePlot) && (
                        <div className="validation-grid" style={{ marginTop: '30px' }}>
                            {(sankeyPlot || alluvialPlot) && (
                                <div className="validation-card">
                                    <h3>🤝 Step 3a: Interaction Flow (Sankey & Alluvial)</h3>
                                    <div className="section-overview">
                                        <strong>Method:</strong> Flow diagrams (ggsankey/ggalluvial) connecting Herb {"->"} Ingredient {"->"} Target. Trace the therapeutic effect and ingredient sharing across multiple herbs.
                                    </div>
                                    {sankeyPlot && <img src={sankeyPlot.url} className="validation-img" alt="Sankey" onClick={() => window.open(sankeyPlot.url, '_blank')} />}
                                    {alluvialPlot && <img src={alluvialPlot.url} className="validation-img" alt="Alluvial" onClick={() => window.open(alluvialPlot.url, '_blank')} style={{ marginTop: '10px' }} />}
                                </div>
                            )}
                            {tcmPlot && (
                                <div className="validation-card">
                                    <h3>🌿 Step 3b: TCM Compound-Target Network</h3>
                                    <div className="section-overview">
                                        <strong>Method:</strong> A tripartite network (Herb {"->"} Molecule {"->"} Target). Node size often corresponds to "degree" (number of connections), highlighting active ingredients and hub targets.
                                    </div>
                                    <img src={tcmPlot.url} className="validation-img" alt="TCM Network" onClick={() => window.open(tcmPlot.url, '_blank')} />
                                </div>
                            )}
                            {ppiPlot && (
                                <div className="validation-card">
                                    <h3>🔗 Step 3c: PPI Network</h3>
                                    <div className="section-overview">
                                        <strong>Method:</strong> Fetches interaction data from the STRING database for your target genes (confidence {" > 0.4"}). Visualizes functional protein-protein clusters.
                                    </div>
                                    <img src={ppiPlot.url} className="validation-img" alt="PPI Network" onClick={() => window.open(ppiPlot.url, '_blank')} />
                                </div>
                            )}
                            {degreePlot && (
                                <div className="validation-card">
                                    <h3>📊 Step 3d: Degree/Hub Plot</h3>
                                    <div className="section-overview">
                                        <strong>Method:</strong> A bar chart ranking targets by how many ingredients target them (Degree). It identifies highly influential "Hub Targets".
                                    </div>
                                    <img src={degreePlot.url} className="validation-img" alt="Degree Plot" onClick={() => window.open(degreePlot.url, '_blank')} />
                                </div>
                            )}
                        </div>
                    )}

                    {/* SECTION 4: ENRICHMENT ANALYSIS */}
                    <div className="analysis-tabs">
                        <div className="tab-headers">
                            <button className={`tab-btn ${activeTab === 'go_bp' ? 'active' : ''}`} onClick={() => setActiveTab('go_bp')}>GO Biological Process</button>
                            <button className={`tab-btn ${activeTab === 'go_mf' ? 'active' : ''}`} onClick={() => setActiveTab('go_mf')}>GO Molecular Function</button>
                            <button className={`tab-btn ${activeTab === 'go_cc' ? 'active' : ''}`} onClick={() => setActiveTab('go_cc')}>GO Cellular Component</button>
                            <button className={`tab-btn ${activeTab === 'do' ? 'active' : ''}`} onClick={() => setActiveTab('do')}>Disease Ontology</button>
                            <button className={`tab-btn ${activeTab === 'kegg' ? 'active' : ''}`} onClick={() => setActiveTab('kegg')}>KEGG Pathway</button>
                        </div>
                        <div className="tab-content">
                            <div className="section-overview" style={{ textAlign: 'left' }}>
                                <strong>Method:</strong> Uses clusterProfiler to statistically test which biological pathways and functions are over-represented in your gene list based on P-value (significance) and count.
                            </div>
                            {renderTabContent()}
                        </div>
                    </div>

                    {/* SECTION 5: PATHWAY GALLERY */}
                    {pathwayMaps.length > 0 && (
                        <div className="pathway-gallery">
                            <h2>🗺️ Step 5: High-Detail Biological Pathway Maps</h2>
                            <div className="section-overview">
                                <strong>Method:</strong> Uses pathview to download official KEGG pathway maps and overlay your data. Hub genes are highlighted in Red/Orange to show drug-pathway intersection points.
                            </div>
                            <div className="gallery-scroll">
                                {pathwayMaps.map((f, i) => (
                                    <div key={i} className="pathway-card" onClick={() => window.open(f.url, '_blank')}>
                                        <img src={f.url} className="pathway-img" alt={f.name} />
                                        <div className="pathway-info"><p>{f.name}</p></div>
                                    </div>
                                ))}
                            </div>
                        </div>
                    )}

                    {/* SECTION 6: ASSET LIST */}
                    <div style={{ marginTop: '40px' }}>
                        <h3>📂 All Generated Assets</h3>
                    </div>
                    {Object.entries(groupedResults).map(([cat, files]) => (
                        files.length > 0 && (
                            <div key={cat} className="results-category">
                                <div className="category-header" onClick={() => toggleCategory(cat)}>
                                    <span>{categoryLabels[cat]} ({files.length})</span>
                                    <span className={`category-arrow ${openCategories[cat] ? 'open' : ''}`}>▶</span>
                                </div>

                                {openCategories[cat] && (
                                    <div className="category-content">
                                        {files.map((file, idx) => (
                                            <div key={idx} style={{ marginBottom: '10px', paddingBottom: '10px', borderBottom: '1px solid #eee' }}>
                                                <div className="result-list-item" style={{ borderBottom: 'none' }}>
                                                    <a href={file.url} className="result-link" target="_blank" rel="noreferrer" download>
                                                        <span className="result-index">No. {file.index}:</span> {file.name}
                                                    </a>
                                                    <div className="action-buttons">
                                                        {file.type === 'csv' ? (
                                                            <a href={file.url} className="download-btn" target="_blank" rel="noreferrer" download>Download CSV</a>
                                                        ) : (
                                                            <>
                                                                <button className="view-btn" onClick={() => window.open(file.url, '_blank')}>View</button>
                                                                <a href={file.url} className="download-btn" target="_blank" rel="noreferrer" download>PNG</a>
                                                                {getAltfomats(file)}
                                                            </>
                                                        )}
                                                    </div>
                                                </div>
                                                {file.type === 'csv' && <CsvPreview file={file} />}
                                            </div>
                                        ))}
                                    </div>
                                )}
                            </div>
                        )
                    ))}
                </div>
            )}

            <div className="logs-section">
                <h2>Pipeline Console Logs {isRunning && <span className="live-indicator">● LIVE</span>}</h2>
                <textarea value={logs} readOnly placeholder="System logs will stream here during execution..." />
            </div>
        </div>
    )
}

export default App
