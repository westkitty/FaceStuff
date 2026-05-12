import os
import json
import asyncio
import subprocess
import shutil
import time
import signal
import uuid
from datetime import datetime
from typing import List, Optional, Dict, Any, Union
from pathlib import Path

from fastapi import FastAPI, UploadFile, File, Form, HTTPException, BackgroundTasks, Query
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, JSONResponse, PlainTextResponse
from pydantic import BaseModel

# Constants
BASE_DIR_STR = "/Users/bigmac/AI/FaceTools"
BASE_DIR = Path(BASE_DIR_STR)
DATA_DIR = BASE_DIR / "data"
UPLOADS_DIR = DATA_DIR / "uploads"
OUTPUTS_DIR = DATA_DIR / "outputs"
JOBS_DIR = DATA_DIR / "jobs"
LOGS_DIR = BASE_DIR / "logs" / "jobs"
STATIC_DIR = BASE_DIR / "static"

for d in [UPLOADS_DIR, OUTPUTS_DIR, JOBS_DIR, LOGS_DIR, STATIC_DIR]:
    d.mkdir(parents=True, exist_ok=True)

app = FastAPI(title="Big Mac FaceTools")

active_jobs: Dict[str, subprocess.Popen] = {}
_cached_help: Optional[str] = None

def get_facefusion_help() -> str:
    global _cached_help
    if _cached_help is None:
        wrapper = str(BASE_DIR / "bin" / "run_facefusion_cli.sh")
        try:
            result = subprocess.run([wrapper, "--help"], capture_output=True, text=True, timeout=15)
            _cached_help = result.stdout + result.stderr
        except Exception:
            _cached_help = ""
    return _cached_help

def normalize_processors(value: Any) -> List[str]:
    if value is None:
        return []
    if isinstance(value, str):
        return [p.strip() for p in value.split(",") if p.strip()]
    if isinstance(value, (list, tuple)):
        return [str(p).strip() for p in value if str(p).strip()]
    return [str(value).strip()] if str(value).strip() else []

def build_facefusion_command(options: Dict[str, Any], source_paths: List[str], target_path: str, output_path: str) -> List[str]:
    help_text = get_facefusion_help()
    wrapper = str(BASE_DIR / "bin" / "run_facefusion_cli.sh")
    cmd = [wrapper]

    if "headless-run" in help_text:
        cmd.append("headless-run")

    if "--source-paths" in help_text:
        for sp in source_paths:
            cmd.extend(["--source-paths", sp])
    else:
        for sp in source_paths:
            cmd.extend(["--source", sp])

    if "--target-path" in help_text:
        cmd.extend(["--target-path", target_path])
    else:
        cmd.extend(["--target", target_path])

    if "--output-path" in help_text:
        cmd.extend(["--output-path", output_path])
    else:
        cmd.extend(["--output", output_path])

    proc_list = normalize_processors(options.get("processors"))
    if proc_list:
        cmd.append("--processors")
        cmd.extend(proc_list)
        
        if "face_enhancer" in proc_list:
            enhancer_model = options.get("face_enhancer_model")
            if enhancer_model and "--face-enhancer-model" in help_text:
                cmd.extend(["--face-enhancer-model", enhancer_model])
            
            enhancer_blend = options.get("face_enhancer_blend")
            if enhancer_blend and "--face-enhancer-blend" in help_text:
                cmd.extend(["--face-enhancer-blend", str(enhancer_blend)])

            enhancer_weight = options.get("face_enhancer_weight")
            if enhancer_weight and "--face-enhancer-weight" in help_text:
                cmd.extend(["--face-enhancer-weight", str(enhancer_weight)])

    out_img_qual = options.get("output_image_quality")
    if out_img_qual and "--output-image-quality" in help_text:
        cmd.extend(["--output-image-quality", str(out_img_qual)])

    out_vid_qual = options.get("output_video_quality")
    if out_vid_qual and "--output-video-quality" in help_text:
        cmd.extend(["--output-video-quality", str(out_vid_qual)])

    trim_end = options.get("trim_frame_end")
    if trim_end and "--trim-frame-end" in help_text:
        cmd.extend(["--trim-frame-end", str(trim_end)])

    extra_args_val = options.get("extra_args")
    if extra_args_val:
        if isinstance(extra_args_val, str):
            extra_list = extra_args_val.split()
        elif isinstance(extra_args_val, (list, tuple)):
            extra_list = [str(x) for x in extra_args_val]
        else:
            extra_list = []
        cmd.extend([x for x in extra_list if x.startswith("--")])

    return cmd

def is_safe_path(base: Path, path: Path) -> bool:
    try:
        resolved_base = base.resolve(strict=False)
        resolved_path = path.resolve(strict=False)
        return resolved_base == resolved_path or resolved_base in resolved_path.parents
    except Exception:
        return False

def sanitize_filename(filename: str) -> str:
    return "".join(c for c in os.path.basename(filename) if c.isalnum() or c in "._-").strip()

def load_job(job_id: str) -> Dict[str, Any]:
    job_file = JOBS_DIR / f"{job_id}.json"
    if not job_file.exists():
        raise HTTPException(status_code=404, detail="Job not found")
    with open(job_file, "r") as f:
        return json.load(f)

def save_job(job_meta: Dict[str, Any]):
    job_meta["updated_at"] = datetime.now().isoformat()
    job_file = JOBS_DIR / f"{job_meta['id']}.json"
    with open(job_file, "w") as f:
        json.dump(job_meta, f, indent=2)

@app.get("/")
async def read_root():
    index_path = STATIC_DIR / "index.html"
    if index_path.exists():
        return FileResponse(str(index_path))
    return JSONResponse({"error": "UI not found"}, status_code=404)

@app.get("/api/health")
async def health():
    return {"status": "ok", "timestamp": datetime.now().isoformat()}

@app.get("/api/status")
async def status():
    return {
        "user": "bigmac",
        "root": BASE_DIR_STR,
        "active_jobs": len(active_jobs),
        "disk_free": shutil.disk_usage(BASE_DIR_STR).free // (1024*1024)
    }

@app.post("/api/diagnostics")
async def diagnostics():
    diag_script = str(BASE_DIR / "bin" / "run_diagnostics.sh")
    if not os.path.exists(diag_script):
        return {"error": "Diagnostics script missing"}
    res = subprocess.run([diag_script], capture_output=True, text=True)
    return {"stdout": res.stdout, "stderr": res.stderr}

@app.get("/api/presets")
async def presets():
    return {
        "fast_test": {"processors": "face_swapper"},
        "balanced": {"processors": "face_swapper,face_enhancer", "face_enhancer_model": "gfpgan_1.4"},
        "fidelity_max": {"processors": "face_swapper,face_enhancer,frame_enhancer", "face_enhancer_model": "codeformer"},
        "damaged_recovery": {"processors": "face_swapper,face_enhancer", "face_enhancer_model": "gfpgan_1.2"},
        "stylized_artwork": {"processors": "face_swapper,face_editor"},
        "video_consistency": {"processors": "face_swapper,face_enhancer", "face_enhancer_model": "gfpgan_1.4"}
    }

@app.get("/api/settings")
async def get_settings():
    settings_path = DATA_DIR / "settings.json"
    if settings_path.exists():
        with open(settings_path, "r") as f:
            return json.load(f)
    return {"theme": "dark", "default_processor": "face_swapper"}

@app.post("/api/settings")
async def post_settings(settings: Dict[str, Any]):
    settings_path = DATA_DIR / "settings.json"
    with open(settings_path, "w") as f:
        json.dump(settings, f)
    return settings

@app.post("/api/preview-command")
async def preview(params: Dict[str, Any]):
    source_paths = params.get("source_paths", ["placeholder_source.jpg"])
    target = params.get("target_path", "placeholder_target.mp4")
    output = params.get("output_path", "placeholder_output.mp4")
    cmd = build_facefusion_command(params, source_paths, target, output)
    return {"command": cmd}

@app.post("/api/jobs")
async def create_job(
    background_tasks: BackgroundTasks,
    source_files: List[UploadFile] = File(...),
    target_file: UploadFile = File(...),
    preset: Optional[str] = Form(None),
    processors: Optional[str] = Form(None),
    face_enhancer_model: Optional[str] = Form(None),
    face_enhancer_blend: Optional[str] = Form(None),
    face_enhancer_weight: Optional[str] = Form(None),
    output_image_quality: Optional[str] = Form(None),
    output_video_quality: Optional[str] = Form(None),
    trim_frame_end: Optional[str] = Form(None),
    extra_args: Optional[str] = Form(None)
):
    job_id = uuid.uuid4().hex
    job_upload_dir = UPLOADS_DIR / job_id
    job_output_dir = OUTPUTS_DIR / job_id
    job_upload_dir.mkdir(parents=True, exist_ok=True)
    job_output_dir.mkdir(parents=True, exist_ok=True)

    source_paths = []
    for sf in source_files:
        if not sf.filename: continue
        sf_name = sanitize_filename(sf.filename)
        sf_path = job_upload_dir / sf_name
        with open(sf_path, "wb") as buffer:
            shutil.copyfileobj(sf.file, buffer)
        source_paths.append(str(sf_path))

    tf_name = sanitize_filename(target_file.filename) if target_file.filename else "target"
    tf_path = job_upload_dir / tf_name
    with open(tf_path, "wb") as buffer:
        shutil.copyfileobj(target_file.file, buffer)

    out_name = f"out_{tf_name}"
    out_path = job_output_dir / out_name

    options = {
        "preset": preset,
        "processors": processors,
        "face_enhancer_model": face_enhancer_model,
        "face_enhancer_blend": face_enhancer_blend,
        "face_enhancer_weight": face_enhancer_weight,
        "output_image_quality": output_image_quality,
        "output_video_quality": output_video_quality,
        "trim_frame_end": trim_frame_end,
        "extra_args": extra_args
    }

    cmd = build_facefusion_command(options, source_paths, str(tf_path), str(out_path))
    log_file = LOGS_DIR / f"{job_id}.log"

    job_meta = {
        "id": job_id,
        "status": "queued",
        "created_at": datetime.now().isoformat(),
        "updated_at": datetime.now().isoformat(),
        "request": {"options": options},
        "source_files": source_paths,
        "target_file": str(tf_path),
        "upload_dir": str(job_upload_dir),
        "output_dir": str(job_output_dir),
        "output_path": str(out_path),
        "output_files": [],
        "log_file": str(log_file),
        "command": cmd
    }

    save_job(job_meta)
    background_tasks.add_task(execute_job, job_id, cmd, str(log_file), str(job_output_dir))
    return job_meta

@app.post("/api/jobs/{job_id}/rerun")
async def rerun_job(job_id: str, background_tasks: BackgroundTasks):
    old_meta = load_job(job_id)
    
    new_job_id = uuid.uuid4().hex
    new_output_dir = OUTPUTS_DIR / new_job_id
    new_output_dir.mkdir(parents=True, exist_ok=True)
    
    source_paths = old_meta.get("source_files", [])
    tf_path = old_meta.get("target_file", "")
    if not tf_path:
        raise HTTPException(status_code=400, detail="Old job missing target file")
    
    tf_name = os.path.basename(tf_path)
    out_name = f"out_{tf_name}"
    out_path = new_output_dir / out_name
    
    options = old_meta.get("request", {}).get("options", {})
    cmd = build_facefusion_command(options, source_paths, tf_path, str(out_path))
    log_file = LOGS_DIR / f"{new_job_id}.log"

    job_meta = {
        "id": new_job_id,
        "status": "queued",
        "created_at": datetime.now().isoformat(),
        "updated_at": datetime.now().isoformat(),
        "request": {"options": options},
        "source_files": source_paths,
        "target_file": tf_path,
        "upload_dir": old_meta.get("upload_dir", ""),
        "output_dir": str(new_output_dir),
        "output_path": str(out_path),
        "output_files": [],
        "log_file": str(log_file),
        "command": cmd
    }
    
    save_job(job_meta)
    background_tasks.add_task(execute_job, new_job_id, cmd, str(log_file), str(new_output_dir))
    return job_meta

async def execute_job(job_id: str, cmd: List[str], log_file: str, output_dir: str):
    meta = load_job(job_id)
    meta["status"] = "running"
    save_job(meta)
    
    try:
        with open(log_file, "w") as lf:
            proc = subprocess.Popen(cmd, stdout=lf, stderr=subprocess.STDOUT, preexec_fn=os.setsid)
            active_jobs[job_id] = proc
            meta["pid"] = proc.pid
            save_job(meta)
            
            proc.wait()
            meta["status"] = "completed" if proc.returncode == 0 else "failed"
            meta["return_code"] = proc.returncode
            
            if proc.returncode == 0 and os.path.exists(output_dir):
                meta["output_files"] = os.listdir(output_dir)
                
    except Exception as e:
        meta["status"] = "error"
        meta["error"] = str(e)
    finally:
        save_job(meta)
        active_jobs.pop(job_id, None)

@app.get("/api/jobs")
async def list_jobs():
    jobs = []
    for f in JOBS_DIR.glob("*.json"):
        try:
            with open(f, "r") as jf:
                jobs.append(json.load(jf))
        except Exception:
            pass
    return sorted(jobs, key=lambda x: x.get("created_at", ""), reverse=True)

@app.get("/api/jobs/{job_id}")
async def get_job(job_id: str):
    return load_job(job_id)

@app.get("/api/jobs/{job_id}/log")
async def get_log(job_id: str):
    log_file = LOGS_DIR / f"{job_id}.log"
    if log_file.exists():
        with open(log_file, "r") as f:
            return PlainTextResponse(f.read())
    return PlainTextResponse("")

@app.post("/api/jobs/{job_id}/cancel")
async def cancel_job(job_id: str):
    meta = load_job(job_id)
    proc = active_jobs.get(job_id)
    if proc:
        try:
            os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
            meta["status"] = "cancelled"
            save_job(meta)
            return {"status": "cancelled"}
        except ProcessLookupError:
            pass
    return {"status": "not_running"}

@app.post("/api/jobs/{job_id}/open-output")
async def open_output(job_id: str):
    meta = load_job(job_id)
    out_dir = Path(meta.get("output_dir", ""))
    if out_dir and is_safe_path(OUTPUTS_DIR, out_dir) and out_dir.exists():
        subprocess.Popen(["open", str(out_dir)])
        return {"ok": True}
    return {"ok": False, "error": "Output directory not found or unsafe"}

@app.get("/api/download/{job_id}/{filename}")
async def download(job_id: str, filename: str):
    meta = load_job(job_id)
    out_dir = Path(meta.get("output_dir", ""))
    
    if not out_dir or not is_safe_path(OUTPUTS_DIR, out_dir):
        raise HTTPException(status_code=403, detail="Invalid output directory")
        
    file_path = out_dir / filename
    if is_safe_path(out_dir, file_path) and file_path.exists():
        return FileResponse(str(file_path))
        
    raise HTTPException(status_code=404, detail="File not found")

app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")
