const $ = (id) => document.getElementById(id);

async function jget(url){ const r=await fetch(url); if(!r.ok) throw new Error(await r.text()); return r.json(); }
async function jpost(url, body){ const r=await fetch(url,{method:'POST',body:body instanceof FormData?body:JSON.stringify(body),headers:body instanceof FormData?{}:{'content-type':'application/json'}}); if(!r.ok) throw new Error(await r.text()); return r.json(); }

async function loadPresets(){
  const presets = await jget('/api/presets');
  const sel = $('presetSelect'); sel.innerHTML='';
  Object.entries(presets).forEach(([k,v])=>{ const o=document.createElement('option'); o.value=k; o.textContent=v.label||k; sel.appendChild(o); });
}

async function loadStatus(){
  $('statusBox').textContent='Loading…';
  try { $('statusBox').textContent = JSON.stringify(await jget('/api/status'), null, 2); }
  catch(e){ $('statusBox').textContent = String(e); }
}

async function diagnostics(){
  $('diagnosticsBox').textContent='Running diagnostics…';
  try { const r=await fetch('/api/diagnostics',{method:'POST'}); $('diagnosticsBox').textContent=await r.text(); }
  catch(e){ $('diagnosticsBox').textContent=String(e); }
}

function formOptions(){
  const fd=new FormData($('jobForm'));
  return {
    preset: fd.get('preset'),
    processors: String(fd.get('processors')||'').split(',').map(s=>s.trim()).filter(Boolean),
    face_enhancer_model: fd.get('face_enhancer_model'),
    face_enhancer_blend: Number(fd.get('face_enhancer_blend')||80),
    face_enhancer_weight: Number(fd.get('face_enhancer_weight')||0.5),
    output_image_quality: Number(fd.get('output_image_quality')||95),
    output_video_quality: Number(fd.get('output_video_quality')||23),
    trim_frame_end: fd.get('trim_frame_end')||null,
    extra_args: String(fd.get('extra_args')||'').split(/\s+/).filter(Boolean)
  };
}

async function preview(){
  $('previewBox').textContent='Building preview…';
  try { $('previewBox').textContent = JSON.stringify(await jpost('/api/preview-command', formOptions()), null, 2); }
  catch(e){ $('previewBox').textContent=String(e); }
}

async function submitJob(ev){
  ev.preventDefault();
  $('submitBox').textContent='Uploading and starting job…';
  try {
    const fd=new FormData($('jobForm'));
    const r=await fetch('/api/jobs',{method:'POST',body:fd});
    const text=await r.text();
    if(!r.ok) throw new Error(text);
    $('submitBox').textContent=text;
    await loadJobs();
  } catch(e){ $('submitBox').textContent=String(e); }
}

async function loadJobs(){
  const box=$('jobs'); box.textContent='Loading jobs…';
  try {
    const jobs=await jget('/api/jobs');
    box.innerHTML='';
    for(const job of jobs){
      const div=document.createElement('div'); div.className='job';
      const outs=(job.output_files||[]).map(f=>`<a href="/api/download/${job.id}/${encodeURIComponent(f)}">${f}</a>`).join(' | ');
      div.innerHTML=`<strong>${job.id}</strong> — ${job.status}<br><small>${job.created_at||''}</small><pre>${JSON.stringify(job.command||[],null,2)}</pre><div>${outs}</div><div class="job-actions"><button data-log="${job.id}">Log</button><button data-cancel="${job.id}">Cancel</button><button data-rerun="${job.id}">Rerun</button><button data-open="${job.id}">Open output folder</button></div><pre id="log-${job.id}"></pre>`;
      box.appendChild(div);
    }
  } catch(e){ box.textContent=String(e); }
}

document.addEventListener('click', async (ev)=>{
  const t=ev.target;
  if(!(t instanceof HTMLElement)) return;
  const log=t.dataset.log, cancel=t.dataset.cancel, rerun=t.dataset.rerun, open=t.dataset.open;
  try{
    if(log){ const r=await fetch(`/api/jobs/${log}/log`); $(`log-${log}`).textContent=await r.text(); }
    if(cancel){ await jpost(`/api/jobs/${cancel}/cancel`,{}); await loadJobs(); }
    if(rerun){ await jpost(`/api/jobs/${rerun}/rerun`,{}); await loadJobs(); }
    if(open){ await jpost(`/api/jobs/${open}/open-output`,{}); }
  }catch(e){ alert(String(e)); }
});

$('refreshStatus').onclick=loadStatus;
$('diagnosticsBtn').onclick=diagnostics;
$('previewBtn').onclick=preview;
$('refreshJobs').onclick=loadJobs;
$('jobForm').addEventListener('submit', submitJob);

loadPresets().then(loadStatus).then(loadJobs);
setInterval(loadJobs, 5000);
