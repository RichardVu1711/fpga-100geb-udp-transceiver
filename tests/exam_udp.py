import pandas as pd
import numpy as np
import os
from pathlib import Path


ROOT_DIR = Path(os.environ.get("ROOT_DIR", os.getcwd()))

def get_vld_wave(file_name, cols):

    df = pd.read_csv(file_name,usecols=cols).rename(columns=cols).iloc[1:-1]
    tvld = df['tvalid'].astype(int).to_numpy()
    vld_idx = np.where(tvld == 1)
    tdata = df['tdata'].to_numpy()[vld_idx]
    return tdata, vld_idx

def get_range_wave(file_name, cols, idx_range):
    df = pd.read_csv(file_name,usecols=cols).rename(columns=cols).iloc[1:-1]
    tvld = df['tvalid'].astype(int).to_numpy()
    vld_idx = range(idx_range[0],idx_range[1], 1)
    tdata = df['tdata'].to_numpy()[vld_idx]
    return tdata, vld_idx



if __name__ == "__main__":
    wave_path = f'{ROOT_DIR}/data/sharedtest/iladata_badcs.csv'
    cols = {
        'design_1_i/ila1/inst/net_slot_0_axis_tdata[511:0]': 'tdata',
        'design_1_i/ila1/inst/net_slot_0_axis_tvalid': 'tvalid',
    }
    get_vld_wave(wave_path, cols)