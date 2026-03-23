% MATLAB Script to Read and Plot Refractive Index Data
filename = 'Au_RefractiveIndex.txt';

% 1. Read the data from the text file
% The file contains 3 columns: Wavelength (nm), Delta, Beta
data = readmatrix(filename);

wavelength = data(:, 1); % First column: Wavelength in nm
delta = data(:, 2);      % Second column: delta
beta = data(:, 3);       % Third column: beta

% 2. Calculate the Complex Refractive Index
% Formula: Index = (1 - delta) - i * beta
refractive_index = (1 - delta) - 1i * beta;

% 3. Plotting the results
figure('Color', 'w');

% Plot Real Part (1 - delta)
subplot(2, 1, 1);
plot(wavelength, real(refractive_index), 'r', 'LineWidth', 1.5);
title('Real Part of Refractive Index (1-\delta)');
xlabel('Wavelength (nm)');
ylabel('Real(n)');
grid on;

% Plot Imaginary Part (beta)
subplot(2, 1, 2);
plot(wavelength, imag(refractive_index), 'b', 'LineWidth', 1.5);
title('Imaginary Part of Refractive Index (-\beta)');
xlabel('Wavelength (nm)');
ylabel('Imag(n)');
grid on;

sgtitle('Refractive Index of Au vs Wavelength');