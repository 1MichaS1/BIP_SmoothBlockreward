% --------------------------------------------------------------------------------------------------
% m-script for FreeMat v4.0 (Matlab clone with GPLv2 license)
% Download for all operating systems: http://freemat.sourceforge.net/download.html
%
% --------------------------------------------------------------------------------------------------
% This script calculates block reward and money supply for a modified, more continuously decreasing,
% Bitcoin emission schedule.
%
% In comparison, original Bitcoin schedule.
%
%
% The new Block Reward (BR) schedule:
%
% d = (2^32-20355337)/2^32 = 4,274,611,959 / 4,294,967,296 = 0.99526065378449857234954833984375;
%
% BR = 50.00000000 BTC for 210,000 blocks (blocks         1..  210,000) --> divide by 2 -->
% BR = 25.00000000 BTC for 210,000 blocks (blocks   210,001..  420,000) --> divide by 2 -->
% BR = 12.50000000 BTC for 210,000 blocks (blocks   420,001..  630,000) --> divide by 2 -->
% BR =  6.25000000 BTC for 105,000 blocks (blocks   630,000..  735,000) --> times d, round down: -->
% BR =  6.22037908 BTC for   1,500 blocks (blocks   735,001..  736,500) --> times d, round up:   -->
% BR =  6.19089855 BTC for   1,500 blocks (blocks   736,501..  738,000) --> times d, round up:   -->
% BR =  6.16165774 BTC for   1,500 blocks (blocks   738,001..  739,500) --> times d, round up:   -->
% BR =  6.13235599 BTC for   1,500 blocks (blocks   739,501..  741,000) --> times d, round up:   -->
% BR =  6.10329264 BTC for   1,500 blocks (blocks   741,001..  742,500) --> times d, round down: -->
% BR =  6.07436702 BTC for   1,500 blocks (blocks   742,501..  744,000) --> times d, round up:   -->
% BR =  6.04557850 BTC for   1,500 blocks (blocks   744,001..  745,500) --> times d, round up:   -->
% BR =  6.01692642 BTC for   1,500 blocks (blocks   745,501..  747,000) --> times d, round up:   -->
% BR =  5.98841013 BTC for   1,500 blocks (blocks   747,001..  748,500) --> times d, round up:   -->
% ...
% ...(always once round down and 4 times round up to full satoshis, and then repeat)...
% ...
% BR =  0.00000220 BTC for   1,500 blocks (blocks 5,518,501..5,520,000) --> times d, round down: -->
% BR =  0.00000218 BTC for   1,500 blocks (blocks x,xxx,xxx..x,xxx,xxx) --> times d, round up:   -->
% BR =  0.00000217 BTC for   1,500 blocks (blocks x,xxx,xxx..x,xxx,xxx) --> times d, round up:   -->
% BR =  0.00000216 BTC for   1,500 blocks (blocks x,xxx,xxx..x,xxx,xxx) --> times d, round up:   -->
% BR =  0.00000215 BTC for   1,500 blocks (blocks x,xxx,xxx..x,xxx,xxx) --> times d, round up:   -->
% BR =  0.00000214 BTC for   1,500 blocks (blocks x,xxx,xxx..x,xxx,xxx) --> times d, round down: -->
% BR =  0.00000212 BTC for   1,500 blocks (blocks x,xxx,xxx..5,529,000) --> times d, round up:   -->
% BR =  0.00000211 BTC for   1,500 blocks (blocks 5,529,001..5,530,500) --> times d, round up:   -->
% BR =  0.00000210 BTC for   4,500 blocks (blocks 5,530,501..5,535,000) --> times d, round down: -->
% BR =  0.00000209 BTC for   7,500 blocks (blocks 5,535,001..5,542,500) --> times d, round down: -->
% BR =  0.00000208 BTC for   7,500 blocks (blocks x,xxx,xxx..x,xxx,xxx) --> times d, round down: -->
% BR =  0.00000207 BTC for   7,500 blocks (blocks x,xxx,xxx..x,xxx,xxx) --> times d, round down: -->
% BR =  0.00000206 BTC for   7,500 blocks (blocks x,xxx,xxx..x,xxx,xxx) --> times d, round down: -->
% BR =  0.00000205 BTC for   7,500 blocks (blocks 5,565,001..5,572,500) --> times d, round down: -->
% ...
% BR =  0.00000004 BTC for   7,500 blocks (blocks 7,072,501..7,080,000) --> times d, round down: -->
% BR =  0.00000003 BTC for   7,500 blocks (blocks 7,080,001..7,087,501) --> times d, round down: -->
% BR =  0.00000002 BTC for   7,500 blocks (blocks 7,087,501..7,095,000) --> times d, round down: -->
% BR =  0.00000001 BTC for   7,500 blocks (blocks 7,095,001..7,102,500)
%
%...and the remaining 1,444,500 satoshis are distributed over the next 1,444,500 blocks:
% BR =  0.00000001 BTC for 1,444,500 blocks (blocks 7,102,501..8,547,000)
%
% ...and finally (after ca. 162.5 years):
% BR =  0.00000000 BTC for blocks >= 8,547,001.
%
% --------------------------------------------------------------------------------------------------
clear all; close all;

delta_t = 210000;%[210000] time between block halvings
block_time_min = 10;%[10]

keep_constant_reward_till_this_block = 3.5*delta_t;%[=0 or =1] (is the same) - for "bip" method only

reward     = 50;% initial reward
reward_bip = 50;% initial reward
reward_bip_2nd = 6.25;% 6.25 BTC initial reward when continuous decay starts
decrease_every=1500;  % block reward gets reduced every 1500 blocks

d = (2^32-20355337)/2^32;% factor of continuous reduction -> 0.01444500 BTC less than 20,999,999.9769 BTC

% lookup tables for faster modulo calculation:
lut_mod=[2:1:decrease_every, 1];% e.g. [2, 3, 4, 1]
lut_mod_cycl=[2:1:5 , 1];% e.g. [2, 3, 4, 5, 1] (round down in 1 of 5 cases)

% Adaptation, to have exactly 20,999,999.9769 BTC at the end:
mine_min = 1;% satoshis to mine minimum
mine_rest = 0;% satoshis to mine once at block height==mine_rest_when
mine_rest_when = 8547001;%block height


Nsim = 35;%[33] nb of "delta_t blocks" intervals to simulate

% --------------------------------------------------------------------------------------------------

accu     = 0;
accu_bip = 0;

rew_org = nan*ones(1,Nsim*delta_t);
rew_bip = nan*ones(1,Nsim*delta_t);
sum_org = nan*ones(1,Nsim*delta_t);
sum_bip = nan*ones(1,Nsim*delta_t);
cnt_dec=1;
cnt_cycl = 1;
for k = 1:Nsim,
    tmpstr1 = num2str(reward,'%011.8f'); tmpstr2 = num2str(reward_bip,'%011.8f');
    pause(0.1);% to avoid artifacts of printing out 0.00000000 or 1.00000000 instead of the proper values
    disp(['BlockReward step ',num2str(k,'%02d'), ': reward_org=', tmpstr1, ', reward_bip=', tmpstr2]);
    pause(0.1);% to avoid artifacts of printing out 0.00000000 or 1.00000000 instead of the proper values
    for block = 1:delta_t,
        accu     = round(1e8*(accu     + reward    ))/1e8;% last satoshi block reward in block 6930000
        accu_bip = round(1e8*(accu_bip + reward_bip))/1e8;
        blockHeight = (k-1)*delta_t+block;
        rew_org(blockHeight) =reward;
        rew_bip(blockHeight) =reward_bip;
        sum_org(blockHeight) = accu;
        sum_bip(blockHeight) = accu_bip;
        % Calculate BlockReward (BR) for next block:
        if blockHeight >= keep_constant_reward_till_this_block,
            if cnt_dec==1,
                if cnt_cycl == 1,
                    reward_bip = floor(reward_bip * d * 1e8)/1e8;
                else
                    reward_bip = ceil(reward_bip * d * 1e8)/1e8;
                end
                % ---------- <SPECIAL> ----------
                reward_bip = max(reward_bip, mine_min*1e-8);% minimum mine_min satoshis
                if blockHeight == mine_rest_when,
                    reward_bip=mine_rest*1e-8;% final money supply will be same as orig. BTC schedule
                elseif blockHeight > mine_rest_when,
                    reward_bip=0;
                end
                % ---------- </SPECIAL> ----------
                cnt_cycl = lut_mod_cycl(cnt_cycl);
            end
            cnt_dec = lut_mod(cnt_dec);
        end
    end
    reward = floor(reward*1e8 / 2)/1e8;
    if blockHeight < keep_constant_reward_till_this_block,
        reward_bip = floor(reward_bip*1e8 / 2)/1e8;
    end
end
accu      % 20,999,999.9769000 BTC
accu_bip
(accu_bip-accu)
%find(rew_bip==0,1) - find(rew_org==0,1)


% ----------Plot: ----------
figure;
hold on;
plot([1:length(rew_org(1:1440/block_time_min:end))]/365.25,rew_org(1:1440/block_time_min:end), ...
    'b');% plot 1 dot per day
plot([1:length(rew_bip(1:1440/block_time_min:end))]/365.25,rew_bip(1:1440/block_time_min:end), ...
    'r');% plot 1 dot per day
grid on;
title('Block Reward vs. Time')
xlabel('Years')
ylabel('Coins')
legend('Bitcoin Original','Bitcoin Continuous')
sizefig(600,500);

figure;
hold on;
plot([1:length(rew_org(1:1440/block_time_min:end))]/365.25,rew_org(1:1440/block_time_min:end), ...
    'b-.');% plot 1 dot per day
plot([1:length(rew_bip(1:1440/block_time_min:end))]/365.25,rew_bip(1:1440/block_time_min:end), ...
    'r-.');% plot 1 dot per day
grid on;
title('Block Reward vs. Time - Zoomed')
xlabel('Years')
ylabel('Coins')
legend('Bitcoin Original','Bitcoin Continuous')
sizefig(600,500);
%axis([50 140 0 1e-3]) % view ooption 1
axis([90 135 0 1e-5]) % view ooption 2
%axis([120 140 0 1e-7]) % view ooption 3

figure;
hold on;
plot([1:length(sum_org(1:1440/block_time_min:end))]/365.25,sum_org(1:1440/block_time_min:end)/1e6, ...
    'b');% plot 1 dot per day
plot([1:length(sum_bip(1:1440/block_time_min:end))]/365.25,sum_bip(1:1440/block_time_min:end)/1e6, ...
    'r');% plot 1 dot per day
grid on;
title('Money Supply vs. Time')
xlabel('Years')
ylabel('Million Coins')
legend('Bitcoin Original','Bitcoin Continuous','location','southeast')
sizefig(600,500);

figure;
hold on;
plot([1:length(sum_org(1:1440/block_time_min:end))]/365.25,sum_org(1:1440/block_time_min:end)/1e6, ...
    'b');% plot 1 dot per day
plot([1:length(sum_bip(1:1440/block_time_min:end))]/365.25,sum_bip(1:1440/block_time_min:end)/1e6, ...
    'r');% plot 1 dot per day
grid on;
title('Money Supply vs. Time - Zoomed Center')
xlabel('Years')
ylabel('Million Coins')
legend('Bitcoin Original','Bitcoin Continuous','location','southeast')
sizefig(600,500);
axis([14 50 19 21.1])

figure;
hold on;
plot([1:length(sum_org(1:1440/block_time_min:end))]/365.25,sum_org(1:1440/block_time_min:end)/1e6, ...
    'b');% plot 1 dot per day
plot([1:length(sum_bip(1:1440/block_time_min:end))]/365.25,sum_bip(1:1440/block_time_min:end)/1e6, ...
    'r');% plot 1 dot per day
grid on;
title('Money Supply vs. Time - Zoomed End')
xlabel('Years')
ylabel('Million Coins')
legend('Bitcoin Original','Bitcoin Continuous','location','southeast')
sizefig(600,500);
axis([50 150. 20.999 21.0002])
