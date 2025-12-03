function fs = get_sampling_rate(timestamp_path)
% timestamp_path = '/run/user/1000/gvfs/smb-share:server=bc-fs01.ad.medctr.ucla.edu,share=honglab2/Tara/Quadrant_therm/mPFC_hm4di/2023/Day3_CNOSAL/Group1/BehavCam_0/timeStamps.csv'
table=readtable(timestamp_path);
total_time = table.TimeStamp_ms_(end) - table.TimeStamp_ms_(2);
total_frames = table.FrameNumber(end) - table.FrameNumber(2);
fs = total_frames/total_time * 1000;
end